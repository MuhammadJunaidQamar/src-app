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

class _SpatialObjectWidgetState extends State<SpatialObjectWidget> {
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
  Size? _viewerSize;
  bool _sceneReady = false;
  String? _globeStatus;

  double _targetRoll = 0, _targetPitch = 0, _targetYaw = 0;
  String? _error;
  StreamSubscription<Model>? _sub;
  Timer? _watchdog;

  // ── Globe animation state ───────────────────────────────────────────────────
  _GlobeMode _gMode = _GlobeMode.pausing;
  int    _stopIdx = 0;
  double _tourT   = 0.0;   // 0..1 progress during TOURING
  double _pauseT  = 0.0;   // elapsed s during PAUSING
  // Quaternion SLERP — matches website's THREE.Quaternion.slerp usage
  // Dart three_js uses instance .slerp(qb, t) not the static 4-arg form.
  three.Quaternion _fromQuat = three.Quaternion(0, 0, 0, 1);
  three.Quaternion _toQuat   = three.Quaternion(0, 0, 0, 1);
  double _velY    = 0.0, _velX = 0.0;
  bool   _dragging = false;
  Timer? _resumeTimer;
  DateTime? _lastPanTime;
  Timer? _debugTimer;
  double _debugY = 0, _debugX = 0;

  // ── Math helpers ────────────────────────────────────────────────────────────
  /// Quadratic InOut — matches the website's Q.Easing.Quadratic.InOut
  static double _easeInOut(double t) {
    if (t < 0.5) return 2 * t * t;
    return -1 + (4 - 2 * t) * t;
  }

  /// Returns the angle equivalent to [to] that is closest to [from]
  /// (shortest arc, avoids spinning the wrong way around).
  static double _shortArc(double from, double to) {
    var d = (to - from) % (2 * math.pi);
    if (d >  math.pi) d -= 2 * math.pi;
    if (d < -math.pi) d += 2 * math.pi;
    return from + d;
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

  // ── Scene setup ─────────────────────────────────────────────────────────────
  Future<void> _setupScene() async {
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
      if (!mounted) return;
      if (planeGltf == null) {
        setState(() => _error = 'Plane GLB parse failed.');
        return;
      }
      final planeNorm = _normalise(planeGltf.scene, 1.6);
      planeNorm.position.y = 3.8;
      tj.scene.add(planeNorm);
      _planeRoot = planeNorm;

      // ── Globe placeholder ────────────────────────────────────────────────────
      // Globe centre is well below the viewport — only the top hemisphere shows.
      final sphereGroup = three.Group();
      sphereGroup.position.y = -5.5;
      sphereGroup.add(three.Mesh(
        three.SphereGeometry(5.5, 32, 20),
        three.MeshBasicMaterial.fromMap({'color': 0x1a4488, 'wireframe': true}),
      ));
      tj.scene.add(sphereGroup);
      _globeRoot = sphereGroup;

      if (mounted) setState(() => _globeStatus = 'Loading globe.glb…');

      // ── Load real globe ──────────────────────────────────────────────────────
      try {
        final globeBytes =
            (await rootBundle.load(_globeAsset)).buffer.asUint8List();
        final globeGltf =
            await three.GLTFLoader(flipY: false).fromBytes(globeBytes);
        if (!mounted) return;
        if (globeGltf != null) {
          final globeNorm = _normalise(globeGltf.scene, 11.0);
          // Apply the same base rotation the website uses on the raw model:
          //   c.rotation.set(-.3, .17, .78)  — from globe.min.js
          globeNorm.rotation.x = -0.3;
          globeNorm.rotation.y =  0.17;
          globeNorm.rotation.z =  0.78;

          tj.scene.remove(sphereGroup);
          final globeGroup = three.Group();
          globeGroup.position.y = -5.5;
          // Source setupGlobe: b.rotation.set(points[1].camera.x - 0.1,
          //                                   points[1].camera.y - 0.1,
          //                                   points[1].camera.z - 0.1)
          globeGroup.rotation.x = _kTourX[0] - 0.1;
          globeGroup.rotation.y = _kTourY[0] - 0.1;
          globeGroup.rotation.z = _kTourZ[0] - 0.1;
          globeGroup.add(globeNorm);
          tj.scene.add(globeGroup);
          _globeRoot = globeGroup;
          if (mounted) setState(() => _globeStatus = 'globe.glb ✓');
        } else {
          if (mounted) setState(() => _globeStatus = 'sphere (globe.glb null)');
        }
      } catch (e, st) {
        if (kDebugMode) debugPrint('Globe: $e\n$st');
        if (mounted) setState(() => _globeStatus = 'sphere (globe err: $e)');
      }

      // ── Animation loop ───────────────────────────────────────────────────────
      _sceneReady = true;
      _watchdog?.cancel();
      const planeSmooth = 0.22;

      tj.addAnimationEvent((double dt) {
        final ddt = dt.clamp(0.001, 0.05);

        // Plane: smooth follow of telemetry
        final p = _planeRoot;
        if (p != null) {
          p.rotation.order = three.RotationOrders.xyz;
          p.rotation.x += (_targetRoll  - p.rotation.x) * planeSmooth;
          p.rotation.y += (_targetPitch - p.rotation.y) * planeSmooth;
          p.rotation.z += (_targetYaw   - p.rotation.z) * planeSmooth;
        }

        // Globe: tour state machine
        final g = _globeRoot;
        if (g == null) return;

        if (_dragging) {
          // Velocity is set from pan events; just apply it.
          g.rotation.y += _velY * ddt;
          g.rotation.x = (g.rotation.x + _velX * ddt).clamp(-1.1, 1.1);
        } else if (_gMode == _GlobeMode.free) {
          // Coast with exponential friction (half-life ≈ 0.7 s)
          final decay = math.pow(0.5, ddt / 0.7) as double;
          _velY *= decay;
          _velX *= decay;
          g.rotation.y += _velY * ddt;
          g.rotation.x = (g.rotation.x + _velX * ddt).clamp(-1.1, 1.1);
        } else if (_gMode == _GlobeMode.pausing) {
          // Slow auto-rotate while at stop — matches source: x-=0.001, y+=0.001
          // per frame @ 60fps → ~0.06 rad/s each axis
          g.rotation.x -= 0.06 * ddt;
          g.rotation.y += 0.06 * ddt;
          _pauseT += ddt;
          if (_pauseT >= _kPauseDur) {
            _stopIdx = (_stopIdx + 1) % _kTourY.length;
            // Build quaternions for SLERP — matches website's rotateObject()
            _fromQuat = three.Quaternion(0, 0, 0, 1)
              ..setFromEuler(three.Euler(g.rotation.x, g.rotation.y, g.rotation.z));
            _toQuat = three.Quaternion(0, 0, 0, 1)
              ..setFromEuler(three.Euler(
                  _kTourX[_stopIdx], _kTourY[_stopIdx], _kTourZ[_stopIdx]));
            _tourT = 0.0;
            _gMode = _GlobeMode.touring;
          }
        } else {
          // TOURING: quaternion SLERP with Quadratic InOut — matches source
          _tourT += ddt / _kLegDur;
          if (_tourT >= 1.0) {
            _tourT = 1.0;
            final e = three.Euler()..setFromQuaternion(_toQuat);
            g.rotation.x = e.x;
            g.rotation.y = e.y;
            g.rotation.z = e.z;
            _gMode  = _GlobeMode.pausing;
            _pauseT = 0.0;
          } else {
            final t = _easeInOut(_tourT);
            // Instance .slerp(qb, t) — returns mutated copy of the receiver
            final q = three.Quaternion(
                _fromQuat.x, _fromQuat.y, _fromQuat.z, _fromQuat.w)
              ..slerp(_toQuat, t);
            final e = three.Euler()..setFromQuaternion(q);
            g.rotation.x = e.x;
            g.rotation.y = e.y;
            g.rotation.z = e.z;
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
  void _ensureViewer(Size size) {
    if (_sameSize(_viewerSize, size)) return;
    _viewerSize = size;
    _watchdog?.cancel();
    _js?.dispose();
    _planeRoot = null;
    _globeRoot = null;
    _sceneReady = false;
    _globeStatus = null;

    _js = three.ThreeJS(
      size: size,
      renderNumber: 0,
      settings: three.Settings(
        antialias: true,
        clearColor: 0x0d1b2e,
        clearAlpha: 1.0,
      ),
      onSetupComplete: () {
        if (mounted) setState(() {});
      },
      setup: _setupScene,
    );
    _watchdog = Timer(const Duration(seconds: 15), () {
      if (!mounted || _sceneReady || _error != null) return;
      setState(() => _error = '3D engine timed out (GPU/driver).');
    });
  }

  bool _sameSize(Size? old, Size next) {
    if (old == null) return false;
    return (old.width - next.width).abs() < _sizeTol &&
        (old.height - next.height).abs() < _sizeTol;
  }

  // ── Drag handlers ────────────────────────────────────────────────────────────
  void _onPanStart(DragStartDetails d) {
    _dragging = true;
    _gMode = _GlobeMode.free; // leave tour mode
    _resumeTimer?.cancel();
    _lastPanTime = DateTime.now();
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
    // Hand off Flutter's fling velocity for realistic momentum
    final fling = details.velocity.pixelsPerSecond;
    _velY = (fling.dx * 0.012).clamp(-8.0, 8.0);
    _velX = (fling.dy * 0.009).clamp(-5.0, 5.0);
    _gMode = _GlobeMode.free;
    // Resume tour 3 s after the user stops interacting
    _resumeTimer?.cancel();
    _resumeTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      final g = _globeRoot;
      if (g == null) return;
      // Build from-quaternion from current globe rotation
      _fromQuat = three.Quaternion(0, 0, 0, 1)
        ..setFromEuler(three.Euler(g.rotation.x, g.rotation.y, g.rotation.z));
      _toQuat = three.Quaternion(0, 0, 0, 1)
        ..setFromEuler(three.Euler(
            _kTourX[_stopIdx], _kTourY[_stopIdx], _kTourZ[_stopIdx]));
      _tourT  = 0.0;
      _gMode  = _GlobeMode.touring;
    });
  }

  // ── Flutter lifecycle ────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    final vm = ViewModel();
    final cached = vm.latestData;
    if (cached != null) _applyTelemetry(cached);
    _sub = vm.dataStream.listen(_applyTelemetry);
    // Refresh debug angle display ~10 times/s
    _debugTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final g = _globeRoot;
      if (g == null || !mounted) return;
      setState(() {
        _debugY = g.rotation.y * 180 / math.pi;
        _debugX = g.rotation.x * 180 / math.pi;
      });
    });
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _resumeTimer?.cancel();
    _debugTimer?.cancel();
    _sub?.cancel();
    _js?.dispose();
    three.loading.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, con) {
        final size = Size(con.maxWidth, con.maxHeight);
        if (size.width >= _minPx && size.height >= _minPx) {
          _ensureViewer(size);
        }
        final js = _js;

        return Stack(
          fit: StackFit.expand,
          children: [
            // 3D scene (three_js has its own internal GestureDetector which
            // would consume events — our capture layer below sits on top)
            if (js != null) Positioned.fill(child: js.build()),
            if (js == null)
              const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Positioned(
                top: 8, left: 8, right: 8,
                child: Material(
                  color: Colors.red.shade900,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 10, bottom: 8,
              child: Text(
                _globeStatus ?? '…',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 11),
              ),
            ),
              // ── DEBUG: drag to desired stop, note Y° value, report to dev ──
              Positioned(
                right: 10, top: 8,
                child: Text(
                  'Y:${_debugY.toStringAsFixed(1)}°  X:${_debugX.toStringAsFixed(1)}°',
                  style: const TextStyle(
                    color: Colors.yellowAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
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
