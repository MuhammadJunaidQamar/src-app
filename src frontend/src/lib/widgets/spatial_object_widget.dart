import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:src/model/model.dart';
import 'package:src/view_model/view_model.dart';
import 'package:three_js/three_js.dart' as three;

enum _GlobeMode { pausing, touring, free }

/// Single [ThreeJS] view: [plane.glb] (telemetry) + [globe.glb] (guided tour /
/// drag) in one scene.
class SpatialObjectWidget extends StatefulWidget {
  const SpatialObjectWidget({super.key});

  @override
  State<SpatialObjectWidget> createState() => _SpatialObjectWidgetState();
}

class _SpatialObjectWidgetState extends State<SpatialObjectWidget>
    with WidgetsBindingObserver {
  static const _planeAsset = 'assets/3d object/plane.glb';
  static const _globeAsset = 'assets/3d object/globe.glb';
  static const double _minPx = 16.0;
  static const double _sizeTol = 20.0;

  // ── Tour waypoints ──────────────────────────────────────────────────────────
  // Exact tour stop Euler(x,y,z) angles from window.globePoints[n].camera
  // in the original Google for Games site (globe.min.js + index.min.js):
  //   [0] "Create great games"    camera {x:0.6527, y:-0.5919, z:-2.8375}
  //   [1] "Connect with players"  camera {x:0.1363, y:-0.4650, z:-0.4580}
  //   [2] "Scale your business"   camera {x:-1.1633, y:-1.0955, z:0.0837}
  // Tour cycles indices 0 → 1 → 2 → 0 ...
  // Source auto-rotate while pausing: x-=0.001/frame, y+=0.001/frame @ 60fps
  static const List<double> _kTourX = [ 0.6527269923798689,  0.13631450928350594, -1.1633540169219667];
  static const List<double> _kTourY = [-0.5919802501399659, -0.4650123639393026,  -1.095540980468304];
  static const List<double> _kTourZ = [-2.837507483903454,  -0.458015913995041,    0.08377304089994568];
  // Source: rotationTime = 1000 ms, easing = Quadratic.InOut
  static const double _kLegDur   = 1.0; // 1 second — matches rotationTime
  static const double _kPauseDur = 3.0; // pause at each stop

  three.ThreeJS? _js;
  three.Object3D? _planeRoot;
  three.Object3D? _globeRoot;
  three.Object3D? _starfieldRoot;
  Size? _viewerSize;
  double _dpr = 1.0;
  bool _sceneReady = false;
  int _setupGen = 0;

  double _targetRoll = 0, _targetPitch = 0, _targetYaw = 0;
  String? _error;
  StreamSubscription<Model>? _sub;
  Timer? _watchdog;

  // ── Globe animation state ───────────────────────────────────────────────────
  _GlobeMode _gMode = _GlobeMode.pausing;
  int    _stopIdx = 0;
  double _tourT   = 0.0;  // 0..1 progress during TOURING
  double _pauseT  = 0.0;  // elapsed s during PAUSING

  // _globeQuat is the AUTHORITATIVE orientation — always kept in sync.
  // Tour, drag, coast, and auto-rotate all read/write this single quaternion.
  three.Quaternion _globeQuat = three.Quaternion(0, 0, 0, 1);
  // SLERP endpoints for tour transitions
  three.Quaternion _fromQuat  = three.Quaternion(0, 0, 0, 1);
  three.Quaternion _toQuat    = three.Quaternion(0, 0, 0, 1);

  double _velY    = 0.0, _velX = 0.0;
  bool   _dragging = false;
  Timer? _resumeTimer;
  DateTime? _lastPanTime;
  Timer? _debugTimer;
  double _planeCurX = 0, _planeCurY = 0, _planeCurZ = 0;
  double _planeTgtX = 0, _planeTgtY = 0, _planeTgtZ = 0;

  // Authoritative plane quaternion — kept in Dart so the bridge never loses sync.
  three.Quaternion _planeQuat = three.Quaternion(0, 0, 0, 1);

  // ── Math helpers ────────────────────────────────────────────────────────────
  /// Quadratic InOut — matches the website's Q.Easing.Quadratic.InOut
  static double _easeInOut(double t) {
    if (t < 0.5) return 2 * t * t;
    return -1 + (4 - 2 * t) * t;
  }

  /// Deep-copy a quaternion into a fresh instance.
  static three.Quaternion _quatCopy(three.Quaternion q) =>
      three.Quaternion(q.x, q.y, q.z, q.w);

  /// Manual dot product (four-component inner product of two unit quaternions).
  static double _quatDot(three.Quaternion a, three.Quaternion b) =>
      a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w;

  /// Return a copy of [to] that is on the same hemisphere as [from],
  /// guaranteeing the shortest-arc SLERP path (avoids the >180° spin).
  static three.Quaternion _shortestArc(
      three.Quaternion from, three.Quaternion to) {
    if (_quatDot(from, to) < 0) {
      return three.Quaternion(-to.x, -to.y, -to.z, -to.w);
    }
    return _quatCopy(to);
  }

  // ── Telemetry helpers ───────────────────────────────────────────────────────
  static ({double roll, double pitch, bool ok}) _tiltFromAccel(Acceleration a) {
    final denom = math.sqrt(a.y * a.y + a.z * a.z);
    if (denom < 1e-4) return (roll: 0.0, pitch: 0.0, ok: false);
    return (
      roll:  math.atan2(a.y, a.z),
      pitch: math.atan2(-a.x, denom),
      ok:    true,
    );
  }

  static double? _yawFromMag(Distance m, double roll, double pitch) {
    final hx = m.x * math.cos(pitch) +
        m.y * math.sin(pitch) * math.sin(roll) +
        m.z * math.sin(pitch) * math.cos(roll);
    final hy = m.y * math.cos(roll) - m.z * math.sin(roll);
    return math.atan2(-hy, hx);
  }

  void _applyTelemetry(Model model) {
    // Prefer the pre-computed orientation from the ESP32.
    // The real CanSat firmware sends roll & pitch in RADIANS but yaw in DEGREES
    // (compass heading). Detect degrees by checking |yaw| > 2π (~6.28).
    if (model.roll != null && model.pitch != null && model.yaw != null) {
      _targetRoll  = model.roll!;
      _targetPitch = model.pitch!;
      final rawYaw = model.yaw!;
      _targetYaw   = rawYaw.abs() > math.pi * 2
          ? rawYaw * math.pi / 180.0   // degrees → radians
          : rawYaw;                    // already radians (sample data)
      return;
    }

    final accel = model.acceleration;
    if (accel == null) return;
    final tilt = _tiltFromAccel(accel);
    _targetRoll  = tilt.roll;
    _targetPitch = tilt.pitch;
    final mag = model.distance;
    if (mag != null && tilt.ok) {
      _targetYaw = _yawFromMag(mag, tilt.roll, tilt.pitch) ?? 0;
    } else {
      final head = model.gps?.heading;
      if (head != null) _targetYaw = head * math.pi / 180.0;
    }
  }

  // ── Scene helpers ───────────────────────────────────────────────────────────
  three.DataTexture? _starSprite;

  /// Soft round star sprite (radial alpha falloff). Without this, [Points]
  /// render as hard squares — this is what makes them look like Mapbox's
  /// small glowing dots.
  three.DataTexture _makeStarSprite() {
    const size = 64;
    final data = Uint8List(size * size * 4);
    const c = (size - 1) / 2.0;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final dx = (x - c) / c;
        final dy = (y - c) / c;
        final d = math.sqrt(dx * dx + dy * dy).clamp(0.0, 1.0);
        // Tight bright core with a smooth glow that fades fully to the edge.
        final a = math.pow(1.0 - d, 2.6).toDouble();
        final i = (y * size + x) * 4;
        data[i] = 255;
        data[i + 1] = 255;
        data[i + 2] = 255;
        data[i + 3] = (a * 255).round().clamp(0, 255);
      }
    }
    final tex = three.DataTexture(
      three.Uint8Array.fromList(data),
      size,
      size,
      three.RGBAFormat,
      three.UnsignedByteType,
    );
    tex.magFilter = three.LinearFilter;
    tex.minFilter = three.LinearFilter;
    tex.generateMipmaps = false;
    tex.needsUpdate = true;
    return tex;
  }

  /// Procedural star shell — sits behind globe/plane inside the same scene.
  three.Points _buildStarLayer({
    required int count,
    required double radius,
    required double pointSize,
    required int seed,
    required double minBright,
    required double maxBright,
  }) {
    final rnd = math.Random(seed);
    final positions = <double>[];
    final colors = <double>[];

    for (var i = 0; i < count; i++) {
      final theta = rnd.nextDouble() * math.pi * 2;
      final phi = math.acos(2 * rnd.nextDouble() - 1);
      final r = radius * (0.9 + rnd.nextDouble() * 0.1);
      positions.addAll([
        r * math.sin(phi) * math.cos(theta),
        r * math.sin(phi) * math.sin(theta),
        r * math.cos(phi),
      ]);
      final brightness = minBright + rnd.nextDouble() * (maxBright - minBright);
      // Subtle warm/cool tint so it isn't a flat white field.
      final cool = rnd.nextDouble() * 0.12;
      colors.addAll([
        (brightness - cool * 0.2).clamp(0.0, 1.0),
        (brightness - cool * 0.4).clamp(0.0, 1.0),
        (brightness + cool).clamp(0.0, 1.0),
      ]);
    }

    final geo = three.BufferGeometry();
    geo.setAttributeFromString(
      'position',
      three.Float32BufferAttribute.fromList(positions, 3, false),
    );
    geo.setAttributeFromString(
      'color',
      three.Float32BufferAttribute.fromList(colors, 3, false),
    );

    final mat = three.PointsMaterial({
      three.MaterialProperty.size: pointSize,
      three.MaterialProperty.map: _starSprite,
      three.MaterialProperty.vertexColors: true,
      three.MaterialProperty.transparent: true,
      three.MaterialProperty.opacity: 1.0,
      three.MaterialProperty.blending: three.AdditiveBlending,
      three.MaterialProperty.depthWrite: false,
      three.MaterialProperty.sizeAttenuation: true,
    });

    final points = three.Points(geo, mat);
    points.frustumCulled = false;
    return points;
  }

  three.Group _buildStarfield() {
    _starSprite ??= _makeStarSprite();
    final field = three.Group();
    // Dense field of faint far stars.
    field.add(_buildStarLayer(
      count: 3200,
      radius: 74,
      pointSize: 0.9,
      seed: 42,
      minBright: 0.28,
      maxBright: 0.6,
    ));
    // Sparse brighter foreground stars.
    field.add(_buildStarLayer(
      count: 260,
      radius: 68,
      pointSize: 1.7,
      seed: 137,
      minBright: 0.7,
      maxBright: 1.0,
    ));
    field.position.setValues(0, -1.0, 0);
    return field;
  }

  three.Group _normalise(three.Object3D model, double targetSize) {
    final box = three.BoundingBox()..setFromObject(model);
    final center = three.Vector3();
    box.getCenter(center);
    final sz = three.Vector3();
    box.getSize(sz);
    final maxDim = math.max(1e-6, math.max(sz.x, math.max(sz.y, sz.z)));
    final s = targetSize / maxDim;

    model.position.x -= center.x;
    model.position.y -= center.y;
    model.position.z -= center.z;

    final inner = three.Group()..add(model);
    final outer = three.Group();
    outer.scale.setValues(s, s, s);
    outer.add(inner);
    return outer;
  }

  /// Write _globeQuat back to the Object3D's Euler rotation.
  void _applyGlobeQuat(three.Object3D g) {
    final e = three.Euler()..setFromQuaternion(_globeQuat);
    g.rotation.x = e.x;
    g.rotation.y = e.y;
    g.rotation.z = e.z;
  }

  /// Build a target quaternion for tour stop [idx] and ensure it is on the
  /// same hemisphere as [from] for a shortest-arc SLERP.
  three.Quaternion _tourTarget(int idx, three.Quaternion from) {
    final raw = three.Quaternion(0, 0, 0, 1)
      ..setFromEuler(three.Euler(_kTourX[idx], _kTourY[idx], _kTourZ[idx]));
    return _shortestArc(from, raw);
  }

  // ── Scene setup ─────────────────────────────────────────────────────────────
  Future<void> _setupScene() async {
    final gen = _setupGen;
    final tj = _js;
    if (tj == null) return;

    // Camera looks down at the top of the massive globe — only the upper
    // hemisphere is visible, cropped at the bottom (matches reference site).
    tj.camera = three.PerspectiveCamera(
      60,
      tj.width / math.max(tj.height, 1),
      0.1,
      300,
    );
    tj.camera.position.setValues(0, 3.0, 9.0);
    tj.camera.lookAt(three.Vector3(0, -1.0, 0));

    tj.scene = three.Scene();
    tj.scene.background = three.Color.fromHex32(0x0d1b2e);

    final starfield = _buildStarfield();
    tj.scene.add(starfield);
    _starfieldRoot = starfield;

    tj.scene.add(three.HemisphereLight(0xb8c6ff, 0x1a2233, 0.8));
    tj.scene.add(three.AmbientLight(0xffffff, 0.6));
    tj.scene.add(
      three.DirectionalLight(0xffffff, 1.2)..position.setValues(4, 8, 6),
    );
    tj.scene.add(
      three.DirectionalLight(0xaaccff, 0.5)..position.setValues(-4, 2, -3),
    );

    try {
      // ── Plane ───────────────────────────────────────────────────────────────
      final planeBytes =
          (await rootBundle.load(_planeAsset)).buffer.asUint8List();
      final planeGltf =
          await three.GLTFLoader(flipY: true).fromBytes(planeBytes);
      if (!mounted || gen != _setupGen) return;
      if (planeGltf == null) {
        setState(() => _error = 'Plane GLB parse failed.');
        return;
      }
      final planeNorm = _normalise(planeGltf.scene, 1.8);
      // Keep the craft in the upper viewport without clipping at the card edge.
      planeNorm.position.y = 1.6;
      tj.scene.add(planeNorm);
      _planeRoot = planeNorm;

      // ── Globe placeholder (shown while globe.glb loads) ──────────────────
      final sphereGroup = three.Group();
      sphereGroup.position.y = -7.0;
      sphereGroup.add(three.Mesh(
        three.SphereGeometry(5.5, 32, 20),
        three.MeshBasicMaterial.fromMap({'color': 0x1a4488, 'wireframe': true}),
      ));
      tj.scene.add(sphereGroup);
      _globeRoot = sphereGroup;

      if (mounted) setState(() {});

      // ── Load real globe ──────────────────────────────────────────────────────
      try {
        final globeBytes =
            (await rootBundle.load(_globeAsset)).buffer.asUint8List();
        final globeGltf =
            await three.GLTFLoader(flipY: false).fromBytes(globeBytes);
        if (!mounted) return;
        if (globeGltf != null) {
          // Increased from 11.0 → 14.0 so the globe fills more of the screen,
          // matching the large cropped appearance on the reference website.
          final globeNorm = _normalise(globeGltf.scene, 14.0);
          // Base model rotation from globe.min.js: c.rotation.set(-.3, .17, .78)
          globeNorm.rotation.x = -0.3;
          globeNorm.rotation.y =  0.17;
          globeNorm.rotation.z =  0.78;

          tj.scene.remove(sphereGroup);
          final globeGroup = three.Group();
          // Pushed down from -5.5 → -7.0 to keep only the top hemisphere
          // visible after the size increase.
          globeGroup.position.y = -7.0;
          // Initial rotation: matches source setupGlobe()
          //   b.rotation.set(points[1].camera.x - 0.1, …)
          globeGroup.rotation.x = _kTourX[0] - 0.1;
          globeGroup.rotation.y = _kTourY[0] - 0.1;
          globeGroup.rotation.z = _kTourZ[0] - 0.1;
          globeGroup.add(globeNorm);
          tj.scene.add(globeGroup);
          _globeRoot = globeGroup;

          // Initialise the authoritative quaternion from the group's Euler angles.
          _globeQuat = three.Quaternion(0, 0, 0, 1)
            ..setFromEuler(three.Euler(
                _kTourX[0] - 0.1, _kTourY[0] - 0.1, _kTourZ[0] - 0.1));

          if (mounted) setState(() {});
        } else {
          if (mounted) setState(() {});
        }
      } catch (e, st) {
        if (kDebugMode) debugPrint('Globe: $e\n$st');
        if (mounted) setState(() {});
      }

      // ── Animation loop ───────────────────────────────────────────────────────
      if (!mounted || gen != _setupGen) return;
      _sceneReady = true;
      _watchdog?.cancel();
      // Time constant derived from the original slerp factor of 0.22/frame @ 60fps:
      //   tau = -1 / (60 * ln(1 - 0.22)) ≈ 0.067 s
      // alpha = 1 - exp(-dt / tau)  →  at 60fps: alpha ≈ 0.22  (same feel as before)
      const double planeTau = 0.067;

      tj.addAnimationEvent((double dt) {
        final ddt = dt.clamp(0.001, 0.05);

        // Slow star drift — replaces the static BackGround.png layer.
        final stars = _starfieldRoot;
        if (stars != null) {
          stars.rotation.y += ddt * 0.012;
          stars.rotation.x += ddt * 0.003;
        }

        // ── Plane: smooth follow of telemetry (quaternion slerp) ─────────────
        final p = _planeRoot;
        if (p != null) {
          final targetQ = three.Quaternion(0, 0, 0, 1)
            ..setFromEuler(three.Euler(_targetRoll, _targetPitch, _targetYaw));

          // Frame-rate-independent exponential smooth toward target.
          final alpha = 1.0 - math.exp(-ddt / planeTau);
          _planeQuat = _quatCopy(_planeQuat)..slerp(targetQ, alpha);

          // Apply directly to the quaternion in one atomic call so
          // onQuaternionChange fires exactly once with the correct value.
          p.quaternion.set(_planeQuat.x, _planeQuat.y, _planeQuat.z, _planeQuat.w);
        }

        // ── Globe: tour / drag state machine ────────────────────────────────
        final g = _globeRoot;
        if (g == null) return;

        if (_dragging) {
          // Both axes use world-space pre-multiplication so that the drag
          // direction always matches the mouse regardless of the current
          // globe orientation (the large Z rotation in the initial state
          // made local-X point backwards, causing the inverted feel).
          final yDelta = three.Quaternion(0, 0, 0, 1)
            ..setFromAxisAngle(three.Vector3(0, 1, 0), _velY * ddt);
          final xDelta = three.Quaternion(0, 0, 0, 1)
            ..setFromAxisAngle(three.Vector3(1, 0, 0), _velX * ddt);
          _globeQuat
            ..premultiply(yDelta)   // world-Y spin
            ..premultiply(xDelta)   // world-X tilt  ← was multiply (local), now premultiply (world)
            ..normalize();
          _applyGlobeQuat(g);

        } else if (_gMode == _GlobeMode.free) {
          // Coast with exponential friction (half-life ≈ 0.7 s)
          final decay = math.pow(0.5, ddt / 0.7) as double;
          _velY *= decay;
          _velX *= decay;
          final yDelta = three.Quaternion(0, 0, 0, 1)
            ..setFromAxisAngle(three.Vector3(0, 1, 0), _velY * ddt);
          final xDelta = three.Quaternion(0, 0, 0, 1)
            ..setFromAxisAngle(three.Vector3(1, 0, 0), _velX * ddt);
          _globeQuat
            ..premultiply(yDelta)
            ..premultiply(xDelta)   // world-X, same as drag
            ..normalize();
          _applyGlobeQuat(g);

        } else if (_gMode == _GlobeMode.pausing) {
          // Slow auto-rotate while at stop:
          //   source: x -= 0.001, y += 0.001 per frame @ 60 fps → 0.06 rad/s
          // Applied as world-axis quaternion deltas to match source behaviour.
          final yDelta = three.Quaternion(0, 0, 0, 1)
            ..setFromAxisAngle(three.Vector3(0, 1, 0),  0.06 * ddt);
          final xDelta = three.Quaternion(0, 0, 0, 1)
            ..setFromAxisAngle(three.Vector3(1, 0, 0), -0.06 * ddt);
          _globeQuat
            ..premultiply(xDelta)  // world-X first (matches Euler order)
            ..premultiply(yDelta)  // world-Y second
            ..normalize();
          _applyGlobeQuat(g);

          _pauseT += ddt;
          if (_pauseT >= _kPauseDur) {
            _stopIdx = (_stopIdx + 1) % _kTourX.length;
            _fromQuat = _quatCopy(_globeQuat);
            // _shortestArc guarantees SLERP takes the <180° path, preventing
            // the "spin the wrong way around" effect on large z differences.
            _toQuat = _tourTarget(_stopIdx, _fromQuat);
            _tourT = 0.0;
            _gMode = _GlobeMode.touring;
          }

        } else {
          // TOURING: quaternion SLERP with Quadratic InOut — matches source
          _tourT += ddt / _kLegDur;
          if (_tourT >= 1.0) {
            _globeQuat = _quatCopy(_toQuat);
            _applyGlobeQuat(g);
            _gMode  = _GlobeMode.pausing;
            _pauseT = 0.0;
          } else {
            final t = _easeInOut(_tourT);
            final q = _quatCopy(_fromQuat)..slerp(_toQuat, t);
            _globeQuat = q;
            _applyGlobeQuat(g);
          }
        }
      });

      if (mounted) setState(() => _error = null);
    } catch (e, st) {
      if (kDebugMode) debugPrint('Scene: $e\n$st');
      if (mounted) setState(() => _error = '3D scene failed: $e');
    }
  }

  // ── Viewer lifecycle ─────────────────────────────────────────────────────────
  void _rebuildViewer(Size size, double dpr) {
    _viewerSize = size;
    _dpr = dpr;
    _watchdog?.cancel();
    _setupGen++;
    _js?.dispose();
    _planeRoot = null;
    _globeRoot = null;
    _starfieldRoot = null;
    _starSprite?.dispose();
    _starSprite = null;
    _sceneReady = false;
    _error = null;
    _planeQuat = three.Quaternion(0, 0, 0, 1);

    _js = three.ThreeJS(
      size: size,
      renderNumber: -1, // Continuous infinite rendering
      settings: three.Settings(
        antialias: true,
        clearColor: 0x0d1b2e,
        clearAlpha: 1.0,
        alpha: false,
        // Render at full native resolution so the scene is crisp on HiDPI displays.
        screenResolution: dpr,
      ),
      onSetupComplete: () {
        if (mounted) setState(() {});
      },
      setup: _setupScene,
    );
    _watchdog = Timer(const Duration(seconds: 20), () {
      if (!mounted || _sceneReady || _error != null) return;
      setState(() => _error = '3D engine timed out — tap to retry');
    });
  }

  void _ensureViewer(Size size, double dpr) {
    if (_sameSize(_viewerSize, size) && _js != null && _error == null) return;
    _rebuildViewer(size, dpr);
  }

  void _retry() {
    final size = _viewerSize;
    if (size == null) return;
    _rebuildViewer(size, _dpr);
    if (mounted) setState(() {});
  }

  bool _sameSize(Size? old, Size next) {
    if (old == null) return false;
    return (old.width - next.width).abs() < _sizeTol &&
        (old.height - next.height).abs() < _sizeTol;
  }

  // ── Drag handlers ────────────────────────────────────────────────────────────
  void _onPanStart(DragStartDetails d) {
    _dragging = true;
    _gMode = _GlobeMode.free;
    _resumeTimer?.cancel();
    _lastPanTime = DateTime.now();
    // _globeQuat is already authoritative — no re-sync needed.
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!_dragging) return;
    final now = DateTime.now();
    final eventDt = _lastPanTime != null
        ? now.difference(_lastPanTime!).inMicroseconds / 1e6
        : 0.016;
    _lastPanTime = now;
    final safeDt = eventDt.clamp(0.004, 0.1);
    _velY = (d.delta.dx / safeDt) * 0.012;
    _velX = (d.delta.dy / safeDt) * 0.009;
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    _lastPanTime = null;
    final fling = details.velocity.pixelsPerSecond;
    _velY = (fling.dx * 0.012).clamp(-8.0, 8.0);
    _velX = (fling.dy * 0.009).clamp(-5.0, 5.0);
    _gMode = _GlobeMode.free;
    // Resume tour 3 s after the user stops interacting
    _resumeTimer?.cancel();
    _resumeTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _fromQuat = _quatCopy(_globeQuat);
      _toQuat   = _tourTarget(_stopIdx, _fromQuat);
      _tourT    = 0.0;
      _gMode    = _GlobeMode.touring;
    });
  }

  // ── Flutter lifecycle ────────────────────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        !_sceneReady &&
        _viewerSize != null) {
      // GPU context often stalls after app switch — recreate the viewer.
      _rebuildViewer(_viewerSize!, _dpr);
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final vm = ViewModel();
    final cached = vm.latestData;
    if (cached != null) _applyTelemetry(cached);
    _sub = vm.dataStream.listen(_applyTelemetry);
    // Refresh plane angle display ~10 times/s
    _debugTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final p = _planeRoot;
      if (p == null || !mounted) return;
      setState(() {
        _planeCurX = p.rotation.x * 180 / math.pi;
        _planeCurY = p.rotation.y * 180 / math.pi;
        _planeCurZ = p.rotation.z * 180 / math.pi;
        _planeTgtX = _targetRoll * 180 / math.pi;
        _planeTgtY = _targetPitch * 180 / math.pi;
        _planeTgtZ = _targetYaw * 180 / math.pi;
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watchdog?.cancel();
    _resumeTimer?.cancel();
    _debugTimer?.cancel();
    _sub?.cancel();
    _setupGen++;
    _starSprite?.dispose();
    _js?.dispose();
    three.loading.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, con) {
        final size = Size(con.maxWidth, con.maxHeight);
        if (size.width >= _minPx && size.height >= _minPx) {
          _ensureViewer(size, MediaQuery.of(ctx).devicePixelRatio);
        }
        final js = _js;

        return Stack(
          fit: StackFit.expand,
          children: [
            if (js != null) Positioned.fill(child: js.build()),
            if (js == null)
              const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Positioned.fill(
                child: Material(
                  color: Colors.black54,
                  child: InkWell(
                    onTap: _retry,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // Debug overlay — shows live/current + target plane rotation
            Positioned(
              right: 10, top: 8,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  border: Border.all(color: Colors.yellowAccent),
                ),
                child: Text(
                  'ROLL: ${_planeCurX.toStringAsFixed(1)}° → ${_planeTgtX.toStringAsFixed(1)}°\n'
                  'PITCH: ${_planeCurY.toStringAsFixed(1)}° → ${_planeTgtY.toStringAsFixed(1)}°\n'
                  'YAW: ${_planeCurZ.toStringAsFixed(1)}° → ${_planeTgtZ.toStringAsFixed(1)}°',
                  style: const TextStyle(
                    color: Colors.yellowAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 10, bottom: 8,
              child: Text(
                'click and drag to interact',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.30),
                  fontSize: 10,
                ),
              ),
            ),
            // Transparent gesture capture layer — must be last (on top) so
            // it intercepts events before three_js's internal handler does.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart:  _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd:    _onPanEnd,
                onPanCancel: () => _onPanEnd(DragEndDetails()),
              ),
            ),
          ],
        );
      },
    );
  }
}
