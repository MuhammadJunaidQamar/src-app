import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:three_js/three_js.dart' as three;

/// Standalone page: only globe.glb, one ThreeJS instance, nothing else.
class GlobeScreen extends StatefulWidget {
  const GlobeScreen({super.key});

  @override
  State<GlobeScreen> createState() => _GlobeScreenState();
}

class _GlobeScreenState extends State<GlobeScreen> {
  static const _asset = 'assets/3d object/globe.glb';

  three.ThreeJS? _js;
  three.Object3D? _root;
  Size? _size;
  String _status = 'Initialising…';
  bool _idleSpin = true;
  bool _dragging = false;
  Timer? _spinTimer;

  void _brighten(three.Object3D obj) {
    obj.traverse((child) {
      if (child is! three.Mesh) return;
      final m = child.material;
      if (m == null) return;
      final list = m is List ? (m as List<dynamic>) : <dynamic>[m];
      for (final mat in list) {
        try {
          if (mat is three.MeshStandardMaterial) {
            mat.emissive = three.Color.fromHex32(0x223344);
            mat.metalness = (mat.metalness * 0.5).clamp(0.0, 1.0);
            mat.roughness = (mat.roughness * 0.85 + 0.15).clamp(0.0, 1.0);
          } else if (mat is three.MeshPhysicalMaterial) {
            mat.emissive = three.Color.fromHex32(0x1a2a3a);
          }
        } catch (_) {}
      }
    });
  }

  Future<void> _setup() async {
    final tj = _js;
    if (tj == null) return;

    tj.camera = three.PerspectiveCamera(
      50,
      tj.width / math.max(tj.height, 1),
      0.1,
      200,
    );
    tj.camera.position.setValues(0, 0, 5);
    tj.camera.lookAt(three.Vector3(0, 0, 0));

    tj.scene = three.Scene();
    tj.scene.background = three.Color.fromHex32(0x0d1520);
    tj.scene.add(three.HemisphereLight(0xb8d0ff, 0x1a2233, 1.0));
    tj.scene.add(three.AmbientLight(0xffffff, 0.7));
    tj.scene.add(
      three.DirectionalLight(0xffffff, 1.4)..position.setValues(5, 8, 5),
    );

    // Always-visible placeholder so we know the engine works
    final placeholder = three.Mesh(
      three.SphereGeometry(1.0, 32, 20),
      three.MeshBasicMaterial.fromMap({'color': 0x1133aa, 'wireframe': true}),
    );
    tj.scene.add(placeholder);
    _root = placeholder;

    if (mounted) setState(() => _status = 'Loading globe.glb…');

    try {
      final bytes = (await rootBundle.load(_asset)).buffer.asUint8List();
      final gltf = await three.GLTFLoader(flipY: false).fromBytes(bytes);
      if (!mounted) return;

      if (gltf == null) {
        if (mounted) setState(() => _status = 'globe.glb → null (parse fail)');
        return;
      }

      final model = gltf.scene;
      _brighten(model);

      // centre + normalise to radius ~1.5
      final box = three.BoundingBox()..setFromObject(model);
      final centre = three.Vector3();
      box.getCenter(centre);
      final sz = three.Vector3();
      box.getSize(sz);
      final maxD = math.max(1e-6, math.max(sz.x, math.max(sz.y, sz.z)));
      final s = 3.0 / maxD;

      // inner group: centre the model
      model.position.x -= centre.x;
      model.position.y -= centre.y;
      model.position.z -= centre.z;
      final inner = three.Group()..add(model);

      // outer group: scale only (no position interaction)
      final outer = three.Group();
      outer.scale.setValues(s, s, s);
      outer.add(inner);

      tj.scene.remove(placeholder);
      tj.scene.add(outer);
      _root = outer;

      if (mounted) setState(() => _status = 'globe.glb ✓');
    } catch (e, st) {
      if (kDebugMode) debugPrint('GlobeScreen: $e\n$st');
      if (mounted) setState(() => _status = 'Error: $e');
    }

    tj.addAnimationEvent((double dt) {
      final r = _root;
      if (r != null && _idleSpin && !_dragging) {
        r.rotation.y += dt * 0.35;
      }
    });
  }

  void _build3D(Size size) {
    if (_size != null &&
        (size.width - _size!.width).abs() < 20 &&
        (size.height - _size!.height).abs() < 20) {
      return;
    }
    _size = size;
    _js?.dispose();
    _root = null;

    _js = three.ThreeJS(
      size: size,
      renderNumber: 0,
      settings: three.Settings(
        antialias: true,
        clearColor: 0x0d1520,
        clearAlpha: 1.0,
      ),
      onSetupComplete: () {
        if (mounted) setState(() {});
      },
      setup: _setup,
    );
  }

  @override
  void dispose() {
    _spinTimer?.cancel();
    _js?.dispose();
    three.loading.clear();
    super.dispose();
  }

  void _panStart(DragStartDetails d) {
    _dragging = true;
    _idleSpin = false;
    _spinTimer?.cancel();
  }

  void _panUpdate(DragUpdateDetails d) {
    final r = _root;
    if (r == null || !_dragging) return;
    r.rotation.y += d.delta.dx * 0.012;
    r.rotation.x = (r.rotation.x + d.delta.dy * 0.01).clamp(-1.4, 1.4);
  }

  void _panEnd(DragEndDetails _) {
    _dragging = false;
    _spinTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _idleSpin = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d1520),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0a0f1a),
        title: Text(
          'Globe  ·  $_status',
          style: const TextStyle(fontSize: 14, color: Colors.white70),
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      body: LayoutBuilder(
        builder: (_, con) {
          final size = Size(con.maxWidth, con.maxHeight);
          if (size.width > 16 && size.height > 16) _build3D(size);
          final js = _js;
          return GestureDetector(
            onPanStart: _panStart,
            onPanUpdate: _panUpdate,
            onPanEnd: _panEnd,
            onPanCancel: () => _panEnd(DragEndDetails()),
            child: js == null
                ? const Center(child: CircularProgressIndicator())
                : js.build(),
          );
        },
      ),
    );
  }
}
