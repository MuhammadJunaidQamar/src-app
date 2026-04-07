import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:src/model/model.dart';
import 'package:src/view_model/view_model.dart';
import 'package:three_js/three_js.dart' as three;

/// Single [ThreeJS] view: [plane.glb] (telemetry) + [globe.glb] (idle spin /
/// drag) in one scene. Two separate `ThreeJS` widgets fail on many Windows
/// ANGLE setups; one texture always composites correctly.
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

  /// Screen Y fraction above which drags rotate the globe (lower part of card).
  static const double _globeDragZoneTop = 0.52;

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
  Timer? _resumeGlobeSpin;

  bool _globeIdleSpin = true;
  bool _draggingGlobe = false;

  static ({double roll, double pitch, bool ok}) _tiltFromAccel(Acceleration a) {
    final denom = math.sqrt(a.y * a.y + a.z * a.z);
    if (denom < 1e-4) return (roll: 0.0, pitch: 0.0, ok: false);
    return (
      roll: math.atan2(a.y, a.z),
      pitch: math.atan2(-a.x, denom),
      ok: true,
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
    _targetRoll = tilt.roll;
    _targetPitch = tilt.pitch;
    final mag = model.distance;
    if (mag != null && tilt.ok) {
      _targetYaw = _yawFromMag(mag, tilt.roll, tilt.pitch) ?? 0;
    } else {
      final head = model.gps?.heading;
      if (head != null) _targetYaw = head * math.pi / 180.0;
    }
  }


  // Correct centering + scaling using nested groups so there is no
  // position/scale interaction:
  //   inner: model shifted so its bounding-box centre is at inner-origin
  //   outer: uniform scale + world position
  three.Group _normalise(three.Object3D model, double targetSize) {
    final box = three.BoundingBox()..setFromObject(model);
    final center = three.Vector3();
    box.getCenter(center);
    final sz = three.Vector3();
    box.getSize(sz);
    final maxDim = math.max(1e-6, math.max(sz.x, math.max(sz.y, sz.z)));
    final s = targetSize / maxDim;

    // shift model so its centroid sits at the inner group's origin
    model.position.x -= center.x;
    model.position.y -= center.y;
    model.position.z -= center.z;

    final inner = three.Group()..add(model);

    // scale is on the outer group — never mixes with position offsets
    final outer = three.Group();
    outer.scale.setValues(s, s, s);
    outer.add(inner);
    return outer;
  }

  Future<void> _setupScene() async {
    final tj = _js;
    if (tj == null) return;

    // Camera at z=10, FoV=55°: sees ±10*tan(27.5°) ≈ ±5.2 units vertically.
    // Plane will live at y=+1.8, globe at y=-1.8 → both safely in frame.
    tj.camera = three.PerspectiveCamera(
      55,
      tj.width / math.max(tj.height, 1),
      0.1,
      300,
    );
    tj.camera.position.setValues(0, 0, 10.0);
    tj.camera.lookAt(three.Vector3(0, 0, 0));

    tj.scene = three.Scene();
    tj.scene.background = three.Color.fromHex32(0x16213e);
    tj.scene.add(three.HemisphereLight(0xb8c6ff, 0x1a2233, 0.8));
    tj.scene.add(three.AmbientLight(0xffffff, 0.6));
    tj.scene.add(
      three.DirectionalLight(0xffffff, 1.2)..position.setValues(4, 8, 6),
    );
    tj.scene.add(
      three.DirectionalLight(0xaaccff, 0.5)..position.setValues(-4, 2, -3),
    );

    // ── Divider line so we can always see the split ────────────────────────
    // (a thin bright ring at y=0 — purely diagnostic, invisible background)

    try {
      // ── Plane ──────────────────────────────────────────────────────────────
      final planeBytes =
          (await rootBundle.load(_planeAsset)).buffer.asUint8List();
      final planeGltf =
          await three.GLTFLoader(flipY: true).fromBytes(planeBytes);
      if (!mounted) return;
      if (planeGltf == null) {
        setState(() => _error = 'Plane GLB parse failed.');
        return;
      }
      final planeNorm = _normalise(planeGltf.scene, 2.4);
      planeNorm.position.y = 1.8;
      tj.scene.add(planeNorm);
      _planeRoot = planeNorm;

      // ── Globe slot: always put a bright wireframe sphere here first ────────
      // If this sphere is visible we know the camera/position is correct.
      final sphereGroup = three.Group();
      sphereGroup.position.y = -1.8;

      final sphere = three.Mesh(
        three.SphereGeometry(1.0, 24, 16),
        three.MeshBasicMaterial.fromMap({
          'color': 0x2255cc,
          'wireframe': true,
        }),
      );
      sphereGroup.add(sphere);
      tj.scene.add(sphereGroup);
      _globeRoot = sphereGroup; // spin target until GLB replaces it

      if (mounted) setState(() => _globeStatus = 'Loading globe.glb…');

      // ── Load real globe on top of the placeholder ──────────────────────────
      try {
        final globeBytes =
            (await rootBundle.load(_globeAsset)).buffer.asUint8List();
        final globeGltf =
            await three.GLTFLoader(flipY: false).fromBytes(globeBytes);
        if (!mounted) return;
        if (globeGltf != null) {
          final globeNorm = _normalise(globeGltf.scene, 2.2);

          // replace sphere with real globe
          tj.scene.remove(sphereGroup);
          final globeGroup = three.Group();
          globeGroup.position.y = -1.8;
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

      // ── Animation ──────────────────────────────────────────────────────────
      _sceneReady = true;
      _watchdog?.cancel();
      const smooth = 0.22;
      tj.addAnimationEvent((double dt) {
        final p = _planeRoot;
        if (p != null) {
          p.rotation.order = three.RotationOrders.xyz;
          p.rotation.x += (_targetRoll - p.rotation.x) * smooth;
          p.rotation.y += (_targetPitch - p.rotation.y) * smooth;
          p.rotation.z += (_targetYaw - p.rotation.z) * smooth;
        }
        final g = _globeRoot;
        if (g != null && _globeIdleSpin && !_draggingGlobe) {
          g.rotation.y += dt * 0.22;
        }
      });

      if (mounted) setState(() => _error = null);
    } catch (e, st) {
      if (kDebugMode) debugPrint('Scene: $e\n$st');
      if (mounted) setState(() => _error = '3D scene failed: $e');
    }
  }

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
        clearColor: 0x16213e,
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

  bool _isGlobeDragZone(Offset local) {
    final h = _viewerSize?.height ?? 0;
    if (h <= 0) return false;
    return local.dy > h * _globeDragZoneTop;
  }

  void _onPanStart(DragStartDetails d) {
    if (!_isGlobeDragZone(d.localPosition)) return;
    _draggingGlobe = true;
    _globeIdleSpin = false;
    _resumeGlobeSpin?.cancel();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final g = _globeRoot;
    if (g == null || !_draggingGlobe) return;
    g.rotation.y += d.delta.dx * 0.01;
    g.rotation.x = (g.rotation.x + d.delta.dy * 0.008).clamp(-1.1, 1.1);
  }

  void _onPanEnd(DragEndDetails d) {
    if (!_draggingGlobe) return;
    _draggingGlobe = false;
    _resumeGlobeSpin?.cancel();
    _resumeGlobeSpin = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _globeIdleSpin = true);
    });
  }

  @override
  void initState() {
    super.initState();
    final vm = ViewModel();
    final cached = vm.latestData;
    if (cached != null) _applyTelemetry(cached);
    _sub = vm.dataStream.listen(_applyTelemetry);
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _resumeGlobeSpin?.cancel();
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

        return GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onPanCancel: () {
            _draggingGlobe = false;
            _resumeGlobeSpin?.cancel();
            _resumeGlobeSpin = Timer(const Duration(milliseconds: 1600), () {
              if (mounted) setState(() => _globeIdleSpin = true);
            });
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (js != null) Positioned.fill(child: js.build()),
              if (js == null)
                const Center(child: CircularProgressIndicator()),
              if (_error != null)
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Material(
                    color: Colors.red.shade900,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 10,
                bottom: 8,
                child: Text(
                  _globeStatus ?? '…',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ),
              Positioned(
                right: 10,
                bottom: 8,
                child: Text(
                  'drag lower area = globe',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
