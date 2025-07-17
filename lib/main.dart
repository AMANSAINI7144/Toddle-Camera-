import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

late List<CameraDescription> _cameras;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Camera Toggle Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Camera Toggle Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  CameraController? controller;
  bool isFrontCamera = true;

  @override
  void initState() {
    super.initState();
    _initializeCamera(isFrontCamera);
  }

  Future<void> _initializeCamera(bool useFront) async {
    try {
      final selectedCamera = _cameras.firstWhere(
            (camera) =>
        camera.lensDirection ==
            (useFront
                ? CameraLensDirection.front
                : CameraLensDirection.back),
        orElse: () => _cameras[0],
      );

      controller?.dispose(); // Dispose previous controller
      controller = CameraController(
        selectedCamera,
        ResolutionPreset.max,
        enableAudio: false,
      );

      await controller!.initialize();
      await controller!.startImageStream((image) {
        print("📸 Stream frame: ${image.width} x ${image.height}");
      });

      if (mounted) setState(() {});
    } catch (e) {
      print("❌ Camera init error: $e");
    }
  }

  void _switchCamera() {
    setState(() {
      isFrontCamera = !isFrontCamera;
    });
    _initializeCamera(isFrontCamera);
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: controller != null && controller!.value.isInitialized
          ? Column(
        children: [
          // Camera preview takes most of the space
          Expanded(
            child: CameraPreview(controller!),
          ),
          // Toggle camera button below the preview
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: FloatingActionButton.extended(
              onPressed: _switchCamera,
              icon: const Icon(Icons.cameraswitch),
              label: Text(isFrontCamera ? "Switch to Back" : "Switch to Front"),
            ),
          ),
        ],
      )
          : const Center(child: CircularProgressIndicator()),
    );
  }

}
