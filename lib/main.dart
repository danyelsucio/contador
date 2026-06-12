import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'fundamentos_page.dart';

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

// ============ BASE DE DATOS ============
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database!= null) return _database!;
    _database = await _initDB('fiscalia.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE carpetas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        volante TEXT UNIQUE NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE campos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        volante TEXT NOT NULL,
        campo TEXT NOT NULL,
        valor TEXT,
        FOREIGN KEY (volante) REFERENCES carpetas (volante)
      )
    ''');
  }

  Future<bool> existeVolante(String volante) async {
    final db = await instance.database;
    final result = await db.query('carpetas', where: 'volante =?', whereArgs: [volante]);
    return result.isNotEmpty;
  }

  Future<int> addVolante(String volante) async {
    final db = await instance.database;
    return await db.insert('carpetas', {'volante': volante});
  }

  Future<int> guardarCampo(String volante, String campo, String valor) async {
    final db = await instance.database;
    return await db.insert(
      'campos',
      {'volante': volante, 'campo': campo, 'valor': valor},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, String>> getCampos(String volante) async {
    final db = await instance.database;
    final result = await db.query('campos', where: 'volante =?', whereArgs: [volante]);
    return {for (var row in result) row['campo'] as String: row['valor'] as String?? ''};
  }

  Future<List<String>> getTodosVolantes() async {
    final db = await instance.database;
    final result = await db.query('carpetas', orderBy: 'id DESC');
    return result.map((row) => row['volante'] as String).toList();
  }
}

// ============ APP ============
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
  String tituloAppBar = 'Fiscalia de Dany el Sucio';
  String volanteActual = '';

  final List<String> listaCampos = [
    'VOLANTE','NOMBRE','CALIDAD','CARPETA','OFICIO','FECHA',
    'RECEPCIÓN','PETICIO','FOJAS','OTROS','FUNDAMENTOS',
    'ORDEN_RESPUESTAS','ESTATUS','EN ESTUDIO','ACCESO',
    'COPIAS_VICT','COPIAS_IMP','AUT_MEDIOS','AUT_ABOGADOS',
    'S_R','COPIAS_AUTENTICAS'
  ];

  // LUPA: DIALOGO WORK/ADD
  void _mostrarDialogoLupa() {
    String volanteInput = '';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ingresa No. Volante'),
          content: TextField(
            keyboardType: TextInputType.number,
            onChanged: (value) => volanteInput = value,
            decoration: const InputDecoration(hintText: "Ej: 12345"),
          ),
          actions: [
            TextButton(
              child: const Text('WORK'),
              onPressed: () async {
                Navigator.pop(context);
                if (volanteInput.isEmpty) return;
                bool existe = await DatabaseHelper.instance.existeVolante(volanteInput);
                if (existe) {
                  setState(() {
                    volanteActual = volanteInput;
                    tituloAppBar = volanteInput;
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Volante no existe. Usa ADD'))
                  );
                }
              },
            ),
            TextButton(
              child: const Text('ADD'),
              onPressed: () async {
                Navigator.pop(context);
                if (volanteInput.isEmpty) return;
                await DatabaseHelper.instance.addVolante(volanteInput);
                setState(() {
                  volanteActual = volanteInput;
                  tituloAppBar = volanteInput;
                });
              },
            ),
          ],
        );
      },
    );
  }

  // DIALOGO PARA GUARDAR CAMPOS
  void _mostrarDialogoCampo(String campo) {
    if (volanteActual.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero selecciona un volante con la lupa'))
      );
      return;
    }
    String valorInput = '';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(campo),
          content: TextField(
            onChanged: (value) => valorInput = value,
            decoration: const InputDecoration(hintText: "Pega o escribe el dato"),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () async {
                await DatabaseHelper.instance.guardarCampo(volanteActual, campo, valorInput);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$campo guardado en $volanteActual'))
                );
              },
            ),
          ],
        );
      },
    );
  }

  // VER BASE DE DATOS
  void _mostrarBaseDatos() async {
    List<String> volantes = await DatabaseHelper.instance.getTodosVolantes();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Carpetas'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: volantes.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(volantes[index]),
              trailing: const Icon(Icons.folder),
              onTap: () async {
                Map<String,String> datos = await DatabaseHelper.instance.getCampos(volantes[index]);
                Navigator.pop(context);
                _mostrarDatosCarpeta(volantes[index], datos);
              },
            ),
          ),
        ),
      ),
    );
  }

  // MOSTRAR DATOS DE CARPETA
  void _mostrarDatosCarpeta(String volante, Map<String, String> datos) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Volante: $volante'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: listaCampos.map((campo) {
              return ListTile(
                title: Text(campo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                subtitle: Text(datos[campo]?? 'Sin datos', style: const TextStyle(fontSize: 14)),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('CERRAR'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFB71C1C),
        title: Text(
          tituloAppBar,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.menu, color: Colors.white),
              onSelected: (value) {
                if (value == 'Base de datos') _mostrarBaseDatos();
                if (value == 'Campos') {
                  showModalBottomSheet(
                    context: context,
                    builder: (context) => ListView.builder(
                      itemCount: listaCampos.length,
                      itemBuilder: (context, index) => ListTile(
                        title: Text(listaCampos[index]),
                        onTap: () {
                         Navigator.pop(context);
                         _mostrarDialogoCampo(listaCampos[index]);
                        },
                      ),
                    ),
                  );
                }
                if (value == 'Fundamentos') {
                  Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FundamentosPage())
                 );
                }
              },
              
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'Base de datos', child: Text('Base de datos')),
                const PopupMenuItem(value: 'Campos', child: Text('Campos')),
                const PopupMenuItem(value: 'Fundamentos', child: Text('Fundamentos')),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: _mostrarDialogoLupa,
            ),
          ],
        ),
        leadingWidth: 100,
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt, color: Colors.white),
            onPressed: () => setState(() => mostrarCamara = true),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
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
            const Text(
              'Hola Adrianayeli',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
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

// SCANNER - IGUAL QUE EL TUYO
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  CameraController? _controller;
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  String textoEscaneado = "Apunta la cámara al expediente";
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
      setState(() {
        if (recognizedText.text.isEmpty) {
          textoEscaneado = "No se detectó texto";
        } else {
          textoEscaneado = recognizedText.text;
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
            height: 250,
            width: double.infinity,
            color: Colors.black87,
            child: SingleChildScrollView(
              child: SelectableText(
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
        Align(
          alignment: Alignment.topLeft,
          child: SafeArea(
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () {
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
