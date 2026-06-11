import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ScannerPage(),
    );
  }
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  CameraController? _controller;
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  String textoEscaneado = 'Toca la cámara para escanear texto';
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _controller = CameraController(cameras[0], ResolutionPreset.high, enableAudio: false);
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _escanearTexto() async {
    if (_controller == null || !_controller!.value.isInitialized || isProcessing) return;
    
    setState(() => isProcessing = true);
    
    try {
      final XFile foto = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(foto.path);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      setState(() {
        textoEscaneado = recognizedText.text.isEmpty 
            ? 'No se detectó texto. Intenta de nuevo.' 
            : recognizedText.text;
        isProcessing = false;
      });
    } catch (e) {
      setState(() {
        textoEscaneado = 'Error: $e';
        isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // BOTÓN CÁMARA ARRIBA
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: IconButton(
                icon: isProcessing 
                    ? const CircularProgressIndicator() 
                    : const Icon(Icons.camera_alt, size: 40),
                onPressed: _escanearTexto,
              ),
            ),
            // TEXTO ESCANEADO EN TODA LA PANTALLA
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: SelectableText(
                  textoEscaneado,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
