import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:three_js/three_js.dart' as three;

class GlobOnlyWidget extends StatefulWidget {
  final bool showPlane;

  const GlobOnlyWidget({super.key, this.showPlane = true});

  @override
  State<GlobOnlyWidget> createState() => _GlobOnlyWidgetState();
}

class _GlobOnlyWidgetState extends State<GlobOnlyWidget> {
  static const _planeAsset = 'assets/3d object/plane.glb';
  static const double _minPx = 16.0;
  static const double _sizeTol = 20.0;
  static const double _planeTargetSize = 4.0;

  three.ThreeJS? _js;
  three.Object3D? _planeRoot;
  Size? _viewerSize;
  bool _sceneReady = false;
  String? _error;
  Timer? _watchdog;

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
        final planeGltf =
            await three.GLTFLoader(flipY: true).fromBytes(planeBytes);
        if (!mounted) return;
        if (planeGltf == null) {
          setState(() => _error = 'Plane GLB parse failed.');
          return;
        }

        final planeNorm = _normalise(planeGltf.scene, _planeTargetSize);
        planeNorm.position.y = 4.2;
        tj.scene.add(planeNorm);
        _planeRoot = planeNorm;
      }

      _sceneReady = true;
      _watchdog?.cancel();
      if (mounted) setState(() => _error = null);
    } catch (e, st) {
      if (kDebugMode) debugPrint('Scene: $e\n$st');
      if (mounted) setState(() => _error = '3D scene failed: $e');
    }
  }

  void _ensureViewer(Size size, double dpr) {
    if (_sameSize(_viewerSize, size)) return;
    _viewerSize = size;
    _watchdog?.cancel();
    _js?.dispose();
    _planeRoot = null;
    _sceneReady = false;
    _error = null;

    _js = three.ThreeJS(
      size: size,
      renderNumber: 0,
      settings: three.Settings(
        antialias: true,
        clearColor: 0x0d1b2e,
        clearAlpha: 0.0,
        alpha: true,
        screenResolution: dpr,
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

  @override
  void dispose() {
    _watchdog?.cancel();
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
            if (js == null) const Center(child: CircularProgressIndicator()),
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
          ],
        );
      },
    );
  }
}
