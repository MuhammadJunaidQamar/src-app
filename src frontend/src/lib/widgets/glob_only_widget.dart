import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:src/model/model.dart';
import 'package:src/view_model/view_model.dart';
import 'package:three_js/three_js.dart' as three;

class GlobOnlyWidget extends StatefulWidget {
  final bool showPlane;

  const GlobOnlyWidget({super.key, this.showPlane = true});

  @override
  State<GlobOnlyWidget> createState() => _GlobOnlyWidgetState();
}

class _GlobOnlyWidgetState extends State<GlobOnlyWidget>
    with WidgetsBindingObserver {
  static const _planeAsset = 'assets/3d object/plane.glb';
  static const double _minPx = 16.0;
  static const double _sizeTol = 20.0;
  static const double _planeTargetSize = 4.0;
  static const double _planeTau = 0.067;

  three.ThreeJS? _js;
  three.Object3D? _planeRoot;
  Size? _viewerSize;
  double _dpr = 1.0;
  bool _sceneReady = false;
  String? _error;
  Timer? _watchdog;
  Timer? _repaintTick;
  StreamSubscription<Model>? _sub;
  int _setupGen = 0;
  int _frameKick = 0;

  double _targetRoll = 0, _targetPitch = 0, _targetYaw = 0;
  three.Quaternion _planeQuat = three.Quaternion(0, 0, 0, 1);

  three.Quaternion _quatCopy(three.Quaternion q) =>
      three.Quaternion(q.x, q.y, q.z, q.w);

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
    if (model.roll != null && model.pitch != null && model.yaw != null) {
      _targetRoll = model.roll!;
      _targetPitch = model.pitch!;
      final rawYaw = model.yaw!;
      _targetYaw =
          rawYaw.abs() > math.pi * 2 ? rawYaw * math.pi / 180.0 : rawYaw;
      return;
    }

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

  Future<void> _setupScene() async {
    final gen = _setupGen;
    final tj = _js;
    if (tj == null) return;

    tj.camera = three.PerspectiveCamera(
      60,
      tj.width / math.max(tj.height, 1),
      0.1,
      300,
    );
    tj.camera.position.setValues(0, 3.0, 9.0);
    tj.camera.lookAt(three.Vector3(0, 0, 0));

    tj.scene = three.Scene();
    // Keep transparent so the dashboard camera feed shows through.
    tj.scene.add(three.HemisphereLight(0xb8c6ff, 0x1a2233, 0.8));
    tj.scene.add(three.AmbientLight(0xffffff, 0.6));
    tj.scene.add(
      three.DirectionalLight(0xffffff, 1.2)..position.setValues(4, 8, 6),
    );
    tj.scene.add(
      three.DirectionalLight(0xaaccff, 0.5)..position.setValues(-4, 2, -3),
    );

    try {
      if (widget.showPlane) {
        final planeBytes =
            (await rootBundle.load(_planeAsset)).buffer.asUint8List();
        if (!mounted || gen != _setupGen) return;
        final planeGltf =
            await three.GLTFLoader(flipY: true).fromBytes(planeBytes);
        if (!mounted || gen != _setupGen) return;
        if (planeGltf == null) {
          setState(() => _error = 'Plane GLB parse failed.');
          return;
        }

        final planeNorm = _normalise(planeGltf.scene, _planeTargetSize);
        planeNorm.position.setValues(0, 0, 0);
        tj.scene.add(planeNorm);
        _planeRoot = planeNorm;
      }

      tj.addAnimationEvent((double dt) {
        final ddt = dt.clamp(0.001, 0.05);
        final p = _planeRoot;
        if (p == null) return;

        final targetQ = three.Quaternion(0, 0, 0, 1)
          ..setFromEuler(three.Euler(_targetRoll, _targetPitch, _targetYaw));

        final alpha = 1.0 - math.exp(-ddt / _planeTau);
        _planeQuat = _quatCopy(_planeQuat)..slerp(targetQ, alpha);
        p.quaternion.set(
          _planeQuat.x,
          _planeQuat.y,
          _planeQuat.z,
          _planeQuat.w,
        );
      });

      if (!mounted || gen != _setupGen) return;
      _sceneReady = true;
      _watchdog?.cancel();
      setState(() => _error = null);
    } catch (e, st) {
      if (kDebugMode) debugPrint('Scene: $e\n$st');
      if (mounted && gen == _setupGen) {
        setState(() => _error = '3D scene failed: $e');
      }
    }
  }

  void _rebuildViewer(Size size, double dpr) {
    _viewerSize = size;
    _dpr = dpr;
    _watchdog?.cancel();
    _setupGen++;
    _js?.dispose();
    _planeRoot = null;
    _sceneReady = false;
    _error = null;
    _planeQuat = three.Quaternion(0, 0, 0, 1);

    _js = three.ThreeJS(
      size: size,
      renderNumber: -1,
      settings: three.Settings(
        antialias: true,
        clearColor: 0x000000,
        clearAlpha: 0.0,
        alpha: true,
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
    // Transparent GPU textures can stop compositing on Windows unless Flutter
    // rebuilds the Texture subtree; kick a light rebuild so attitude shows.
    _repaintTick = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted || _planeRoot == null) return;
      setState(() => _frameKick++);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watchdog?.cancel();
    _repaintTick?.cancel();
    _sub?.cancel();
    _setupGen++;
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
            if (js != null)
              Positioned.fill(
                // Tiny opacity kick: forces Flutter to recomposite the
                // transparent Texture without recreating the ThreeJS instance.
                child: Opacity(
                  opacity: 0.999 + (_frameKick % 2) * 0.001,
                  child: js.build(),
                ),
              ),
            if (js == null) const Center(child: CircularProgressIndicator()),
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
          ],
        );
      },
    );
  }
}
