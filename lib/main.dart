import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool mostrarCamara = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 1. APPBAR NUEVO CON LOS 4 BOTONES
      appBar: AppBar(
        backgroundColor: Colors.black,
        // BOTONES IZQUIERDA: Menú hamburguesa + Lupa
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 2. BOTÓN MENÚ 3 RAYITAS
            PopupMenuButton<String>(
              icon: const Icon(Icons.menu, color: Colors.white),
              onSelected: (value) {
                // 5. OPCIONES DEL MENÚ IZQUIERDO
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Seleccionaste: $value')),
                );
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'Base de datos', child: Text('Base de datos')),
                const PopupMenuItem(value: 'Campos', child: Text('Campos')),
                const PopupMenuItem(value: 'Fundamentos', child: Text('Fundamentos')),
              ],
            ),
            // 3. BOTÓN LUPA
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Búsqueda presionada')),
                );
              },
            ),
          ],
        ),
        leadingWidth: 100, // Ancho para que quepan los 2 botones

        // 1. QUITAMOS EL TEXTO "Scanner curp"
        title: const Text(''),

        // BOTONES DERECHA: Cámara + 3 Puntitos
        actions: [
          // 5. BOTÓN CÁMARA - AQUÍ SE ACTIVA EL SCANNER
          IconButton(
            icon: const Icon(Icons.camera_alt, color: Colors.white),
            onPressed: () {
              setState(() => mostrarCamara = true); // 7. Solo aquí prende la cámara
            },
          ),
          // 4. BOTÓN MENÚ 3 PUNTITOS
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              // 6. OPCIONES DEL MENÚ DERECHO
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Seleccionaste: $value')),
              );
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'Pedidos', child: Text('Pedidos')),
              const PopupMenuItem(value: 'Recibidos', child: Text('Recibidos')),
              const PopupMenuItem(value: 'Pendientes', child: Text('Pendientes')),
            ],
          ),
        ],
      ),

      // 6. SI mostrarCamara = true MUESTRA SCANNER, SI NO MUESTRA EL HOME
      body: mostrarCamara? const ScannerScreen() : const BeastieHome(),
    );
  }
}

// PANTALLA DE INICIO CON BEASTIE
class BeastieHome extends StatelessWidget {
  const BeastieHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 6. TEXTO CENTRADO
            const Text(
              'Hola Adrianayeli',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            // 6. IMAGEN DE BEASTIE
            Image.asset(
              'assets/images/beastie.jpg',
              height: 200,
            ),
          ],
        ),
      ),
    );
  }
}

// TU SCANNER DE ANTES, AHORA SEPARADO
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  CameraController? _controller;
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  String textoEscaneado = "Apunta la cámara a la CURP";
  bool isBusy = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _controller = CameraController(cameras[0], ResolutionPreset.high);
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _escanear() async {
  if (_controller == null || isBusy) return;
  setState(() => isBusy = true);
  
  try {
    final foto = await _controller!.takePicture();
    final inputImage = InputImage.fromFilePath(foto.path);
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    
    // QUITAMOS EL REGEX Y MOSTRAMOS TODO EL TEXTO
    setState(() {
      if (recognizedText.text.isEmpty) {
        textoEscaneado = "No se detectó texto";
      } else {
        textoEscaneado = recognizedText.text; // TODO EL TEXTO COMPLETO
      }
    });
  } catch (e) {
    setState(() {
      textoEscaneado = "Error: $e";
    });
  } finally {
    setState(() => isBusy = false);
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
    if (_controller == null ||!_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        CameraPreview(_controller!),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(12),
            height: 250, // Más altura
            width: double.infinity,
            color: Colors.black87,
            child: SingleChildScrollView( // ESTO LE DA SCROLL
              child: SelectableText( // Y ESTO LO HACE COPIABLE
                textoEscaneado,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
       ),
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: FloatingActionButton(
              onPressed: isBusy? null : _escanear,
              child: isBusy
                 ? const CircularProgressIndicator(color: Colors.white)
                  : const Icon(Icons.camera_alt),
            ),
          ),
        ),
        // BOTÓN PARA REGRESAR AL HOME
        Align(
          alignment: Alignment.topLeft,
          child: SafeArea(
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () {
                // Busca el HomeScreen padre y oculta la cámara
                final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                homeState?.setState(() => homeState.mostrarCamara = false);
              },
            ),
          ),
        ),
      ],
    );
  }
}
