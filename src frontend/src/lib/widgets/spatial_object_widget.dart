import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:src/model/model.dart';
import 'package:src/view_model/view_model.dart';
import 'package:three_js/three_js.dart' as three;

/// Live 3D orientation of [plane.glb] from WebSocket [Model] via [ViewModel].
///
/// Uses [three_js] (Dart + Flutter Angle). Roll/pitch from accelerometer; yaw from
/// magnetometer / GPS heading.
///
/// [ThreeJS] is created with an explicit [Size] from layout so the GPU texture matches
/// the card (full [MediaQuery] size on Windows often breaks ANGLE allocation).
class SpatialObjectWidget extends StatefulWidget {
  const SpatialObjectWidget({super.key});

  @override
  State<SpatialObjectWidget> createState() => _SpatialObjectWidgetState();
}

class _SpatialObjectWidgetState extends State<SpatialObjectWidget> {
  static const _assetGlb = 'assets/3d object/plane.glb';

  three.ThreeJS? _threeJs;
  bool _scheduleCreate = false;
  three.Object3D? _planeRoot;
  StreamSubscription<Model>? _sub;

  double _targetRoll = 0;
  double _targetPitch = 0;
  double _targetYaw = 0;

  String? _loadError;

  static ({double roll, double pitch, bool ok}) _tiltFromAccel(Acceleration a) {
    final denom = math.sqrt(a.y * a.y + a.z * a.z);
    if (denom < 1e-4) {
      return (roll: 0.0, pitch: 0.0, ok: false);
    }
    final roll = math.atan2(a.y, a.z);
    final pitch = math.atan2(-a.x, denom);
    return (roll: roll, pitch: pitch, ok: true);
  }

  static double? _yawFromMag(
    Distance m,
    double roll,
    double pitch,
  ) {
    final cr = math.cos(roll);
    final sr = math.sin(roll);
    final cp = math.cos(pitch);
    final sp = math.sin(pitch);
    final hx = m.x * cp + m.y * sp * sr + m.z * sp * cr;
    final hy = m.y * cr - m.z * sr;
    return math.atan2(-hy, hx);
  }

  static ({double roll, double pitch, double yaw}) _orientationRadians(Model model) {
    final accel = model.acceleration;
    if (accel == null) {
      return (roll: 0, pitch: 0, yaw: 0);
    }
    final tilt = _tiltFromAccel(accel);
    double yaw = 0;
    final mag = model.distance;
    if (mag != null && tilt.ok) {
      yaw = _yawFromMag(mag, tilt.roll, tilt.pitch) ?? 0;
    } else {
      final head = model.gps?.heading;
      if (head != null) {
        yaw = head * math.pi / 180.0;
      }
    }
    return (roll: tilt.roll, pitch: tilt.pitch, yaw: yaw);
  }

  void _applyModel(Model model) {
    final t = _orientationRadians(model);
    _targetRoll = t.roll;
    _targetPitch = t.pitch;
    _targetYaw = t.yaw;
  }

  Future<void> _setupScene() async {
    final tj = _threeJs;
    if (tj == null) return;

    tj.camera = three.PerspectiveCamera(
      45,
      tj.width / math.max(tj.height, 1),
      0.01,
      500,
    );
    tj.camera.position.setValues(1.2, 0.9, 2.2);

    tj.scene = three.Scene();

    tj.scene.add(three.AmbientLight(0xffffff, 0.55));
    final key = three.DirectionalLight(0xffffff, 1.0);
    key.position.setValues(3, 5, 4);
    tj.scene.add(key);
    final fill = three.DirectionalLight(0xaaccff, 0.35);
    fill.position.setValues(-3, 1, -2);
    tj.scene.add(fill);

    try {
      final bytes =
          (await rootBundle.load(_assetGlb)).buffer.asUint8List();
      final loader = three.GLTFLoader(flipY: true);
      final gltf = await loader.fromBytes(bytes);
      if (!mounted) return;
      if (gltf == null) {
        setState(() => _loadError = 'Could not load plane model.');
        return;
      }

      final root = gltf.scene;
      final box = three.BoundingBox()..setFromObject(root);
      final center = three.Vector3();
      box.getCenter(center);
      root.position.sub(center);

      final sizeVec = three.Vector3();
      box.getSize(sizeVec);
      final maxDim = math.max(
        1e-3,
        math.max(sizeVec.x, math.max(sizeVec.y, sizeVec.z)),
      );
      tj.camera.position.setValues(
        maxDim * 0.9,
        maxDim * 0.65,
        maxDim * 1.8,
      );
      (tj.camera as three.PerspectiveCamera).near = maxDim / 100;
      (tj.camera as three.PerspectiveCamera).far = maxDim * 100;
      (tj.camera as three.PerspectiveCamera).updateProjectionMatrix();
      tj.camera.lookAt(three.Vector3.zero());

      tj.scene.add(root);
      _planeRoot = root;

      const smooth = 0.22;
      tj.addAnimationEvent((_) {
        final plane = _planeRoot;
        if (plane == null) return;
        plane.rotation.order = three.RotationOrders.xyz;
        plane.rotation.x += (_targetRoll - plane.rotation.x) * smooth;
        plane.rotation.y += (_targetPitch - plane.rotation.y) * smooth;
        plane.rotation.z += (_targetYaw - plane.rotation.z) * smooth;
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('SpatialObjectWidget GLB load failed: $e\n$st');
      }
      if (mounted) {
        setState(() => _loadError = '3D load error');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final vm = ViewModel();
    final cached = vm.latestData;
    if (cached != null) {
      _applyModel(cached);
    }
    _sub = vm.dataStream.listen(_applyModel);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _threeJs?.dispose();
    three.loading.clear();
    super.dispose();
  }

  void _ensureThreeJsScheduled(Size layoutSize) {
    if (_threeJs != null || _scheduleCreate) return;
    if (layoutSize.width < 8 || layoutSize.height < 8) return;
    _scheduleCreate = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _threeJs = three.ThreeJS(
          size: layoutSize,
          settings: three.Settings(
            alpha: true,
            antialias: true,
            clearColor: 0x16213e,
            clearAlpha: 1.0,
          ),
          onSetupComplete: () {
            if (mounted) setState(() {});
          },
          setup: _setupScene,
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        if (w.isFinite && h.isFinite && w >= 8 && h >= 8) {
          _ensureThreeJsScheduled(Size(w, h));
        }

        final tj = _threeJs;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loadError != null)
              Material(
                color: Colors.red.shade900.withValues(alpha: 0.85),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    _loadError!,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            Expanded(
              child: tj == null
                  ? const Center(child: CircularProgressIndicator())
                  : tj.build(),
            ),
          ],
        );
      },
    );
  }
}
