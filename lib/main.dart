import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Camera initialization error: $e');
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ML Kit Image Labeling',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: CameraScreen(),
    );
  }
}
class ScannerFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    const double cornerLength = 30;
    const double padding = 20; // inner margin to avoid touching the edges

    final left = padding;
    final top = padding;
    final right = size.width - padding;
    final bottom = size.height - padding;

    // Top-left corner
    canvas.drawLine(Offset(left, top), Offset(left + cornerLength, top), paint);
    canvas.drawLine(Offset(left, top), Offset(left, top + cornerLength), paint);

    // Top-right corner
    canvas.drawLine(Offset(right, top), Offset(right - cornerLength, top), paint);
    canvas.drawLine(Offset(right, top), Offset(right, top + cornerLength), paint);

    // Bottom-left corner
    canvas.drawLine(Offset(left, bottom), Offset(left + cornerLength, bottom), paint);
    canvas.drawLine(Offset(left, bottom), Offset(left, bottom - cornerLength), paint);

    // Bottom-right corner
    canvas.drawLine(Offset(right, bottom), Offset(right - cornerLength, bottom), paint);
    canvas.drawLine(Offset(right, bottom), Offset(right, bottom - cornerLength), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}


class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isFrontCamera = false;
  bool _isProcessing = false;
  String _resultText = '';
  File? _imageFile; // ✅ declared here

  late final ImageLabeler _imageLabeler;

  @override
  void initState() {
    super.initState();
    _imageLabeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.5),
    );
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final lensDirection =
    _isFrontCamera ? CameraLensDirection.front : CameraLensDirection.back;

    final selectedCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == lensDirection,
      orElse: () => cameras.first,
    );

    _controller = CameraController(selectedCamera, ResolutionPreset.medium);

    try {
      await _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Camera initialization failed: $e');
    }
  }

  Future<void> _switchCamera() async {
    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });
    await _controller?.dispose();
    await _initializeCamera();
  }

  Future<void> _captureAndLabelImage() async {
    if (!(_controller?.value.isInitialized ?? false)) return;

    try {
      setState(() {
        _isProcessing = true;
        _resultText = '';
        _imageFile = null;
      });

      // Capture image
      final XFile pictureFile = await _controller!.takePicture();
      _imageFile = File(pictureFile.path);
      final inputImage = InputImage.fromFilePath(pictureFile.path);

      // Process the image
      final List<ImageLabel> labels =
      await _imageLabeler.processImage(inputImage);

      setState(() {
        _resultText = labels.isEmpty
            ? 'No labels found'
            : labels
            .map((e) =>
        '${e.label} (${(e.confidence * 100).toStringAsFixed(2)}%)')
            .join('\n');
      });
    } catch (e) {
      setState(() {
        _resultText = 'Error during image labeling: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _imageLabeler.close();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("ML Kit Camera App"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Camera preview with padding and fixed height
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(_controller!),
                      CustomPaint(
                        painter: ScannerFramePainter(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Captured image preview
            _imageFile != null
                ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_imageFile!, height: 250),
              ),
            )
                : const Icon(Icons.image, size: 100, color: Colors.grey),

            const SizedBox(height: 16),

            // Capture button
            Center(
              child: ElevatedButton.icon(
                onPressed: _captureAndLabelImage,
                icon: const Icon(Icons.camera),
                label: const Text('Capture Image'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ML result container
            _isProcessing
                ? const Center(child: CircularProgressIndicator())
                : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.inversePrimary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _resultText.isEmpty ? "No results yet" : _resultText,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _switchCamera,
        child: const Icon(Icons.cameraswitch),
      ),
    );
  }

}
