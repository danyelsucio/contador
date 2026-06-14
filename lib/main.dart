import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'fundamentos_page.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'drive_helper.dart';
import 'package:csv/csv.dart';
// ▼▼ AGREGA ESTOS 3 IMPORTS ▼▼▼
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
// ▲▲▲ FIN IMPORTS ▲▲▲

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Error cámaras: $e');
    cameras = [];
  }

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

  return await openDatabase(
    path,
    version: 1,
    onCreate: _createDB,
    singleInstance: true,
  );
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
    await db.execute('''
      CREATE TABLE pedidos (
        folio TEXT PRIMARY KEY NOT NULL,
        volante TEXT NOT NULL,
        carpeta TEXT NOT NULL,
        mesa TEXT NOT NULL,
        fecha TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE recibidos (
        folio TEXT PRIMARY KEY NOT NULL,
        volante TEXT NOT NULL,
        carpeta TEXT NOT NULL,
        mesa TEXT NOT NULL,
        fecha TEXT
      )
    ''');
        await db.execute('''
      CREATE TABLE plantillas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        ruta_local TEXT NOT NULL,
        drive_id TEXT NOT NULL,
        tipo TEXT NOT NULL,
        fecha_descarga TEXT
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

Future<int> addPedido(String folio, String volante, String carpeta, String mesa) async {
  final db = await instance.database;
  return await db.insert(
    'pedidos',
    {'folio': folio, 'volante': volante, 'carpeta': carpeta, 'mesa': mesa, 'fecha': DateTime.now().toString()},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<Map<String, dynamic>?> getPedidoPorFolio(String folio) async {
  final db = await instance.database;
  final result = await db.query('pedidos', where: 'folio =?', whereArgs: [folio]);
  if (result.isNotEmpty) return result.first;
  return null;
}

Future<int> addRecibido(String folio, String volante, String carpeta, String mesa) async {
  final db = await instance.database;
  return await db.insert(
    'recibidos',
    {'folio': folio, 'volante': volante, 'carpeta': carpeta, 'mesa': mesa, 'fecha': DateTime.now().toString()},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<List<Map<String, dynamic>>> getPedidos() async {
  final db = await instance.database;
  return await db.query('pedidos', orderBy: 'fecha DESC');
}

Future<List<Map<String, dynamic>>> getRecibidos() async {
  final db = await instance.database;
  return await db.query('recibidos', orderBy: 'fecha DESC');
}

 Future<List<Map<String, dynamic>>> getPendientes() async {
   final db = await instance.database;
   return await db.rawQuery('''
     SELECT p.* FROM pedidos p
     LEFT JOIN recibidos r ON p.folio = r.folio
     WHERE r.folio IS NULL
   ''');
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

  void _mostrarBaseDatos() async {
  List<String> volantes = await DatabaseHelper.instance.getTodosVolantes();

  int totalPedidos = (await DatabaseHelper.instance.getPedidos()).length;
  int totalRecibidos = (await DatabaseHelper.instance.getRecibidos()).length;
  int totalPendientes = (await DatabaseHelper.instance.getPendientes()).length;

  if (!mounted) return;
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Base de datos'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.send, color: Colors.blue),
              title: const Text('PEDIDOS', style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: Text('$totalPedidos', style: const TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                _mostrarListaPedidos();
              },
            ),
            ListTile(
              leading: const Icon(Icons.inbox, color: Colors.green),
              title: const Text('RECIBIDOS', style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: Text('$totalRecibidos', style: const TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                _mostrarListaRecibidos();
              },
            ),
            ListTile(
              leading: const Icon(Icons.pending_actions, color: Colors.orange),
              title: const Text('PENDIENTES', style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: Text('$totalPendientes', style: const TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                _dialogoPendientes();
              },
            ),
            const Divider(thickness: 2),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('VOLANTES', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
          ...volantes.map((volante) => ListTile(
              title: Text(volante),
              trailing: const Icon(Icons.folder),
              onTap: () async {
                Navigator.pop(context);
                String volanteKey = volante;
                Map<String, String> campos = await DatabaseHelper.instance.getCampos(volanteKey);
                if (!mounted) return;
                _mostrarDetallesVolante(campos, volanteKey);
              },
            )).toList(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CERRAR'),
        ),
      ],
    ),
  );
}

// ▼▼▼ FUNCIÓN RESTAURADA AQUÍ ▼▼▼
Future<void> _descargarPlantillas(BuildContext context) async {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Buscando plantillas en Drive...')),
  );

  try {
    final GoogleSignIn googleSignIn = GoogleSignIn(
      scopes: [drive.DriveApi.driveReadonlyScope],
    );

    final GoogleSignInAccount? account = await googleSignIn.signInSilently();
    if (account == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Inicia sesión primero')),
      );
      return;
    }

    final authHeaders = await account.authHeaders;
    final client = GoogleAuthClient(authHeaders);
    final driveApi = drive.DriveApi(client);

    final folderResult = await driveApi.files.list(
      q: "mimeType='application/vnd.google-apps.folder' and name='Plantillas' and trashed=false",
      $fields: "files(id, name)",
    );

    if (folderResult.files!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crea carpeta Plantillas en Drive')),
      );
      return;
    }

    final folderId = folderResult.files!.first.id;
    final filesResult = await driveApi.files.list(
      q: "'$folderId' in parents and trashed=false",
      $fields: "files(id, name, mimeType)",
    );

    if (filesResult.files!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Carpeta Plantillas vacía')),
      );
      return;
    }

    final String savePath = '/storage/emulated/0/Download';
    int contador = 0;

    for (var file in filesResult.files!) {
      drive.Media fileData;
      String fileName = file.name!;

      if (file.mimeType == 'application/vnd.google-apps.document') {
        fileData = await driveApi.files.export(
          file.id!,
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        ) as drive.Media;
        fileName = '${file.name}.docx';
      }
      else if (file.mimeType == 'application/vnd.google-apps.spreadsheet') {
        fileData = await driveApi.files.export(
          file.id!,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ) as drive.Media;
        fileName = '${file.name}.xlsx';
      }
      else {
        fileData = await driveApi.files.get(
          file.id!,
          downloadOptions: drive.DownloadOptions.fullMedia,
        ) as drive.Media;
      }

      final saveFile = File('$savePath/$fileName');
      final bytes = await fileData.stream.fold<List<int>>([], (p, e) => p..addAll(e));
      await saveFile.writeAsBytes(bytes);
      contador++;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Descargadas $contador plantillas en Descargas')),
    );

  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
// ▲▲▲ FIN FUNCIÓN RESTAURADA ▲▲▲

void _mostrarListaPedidos() async {
  List<Map<String, dynamic>> pedidos = await DatabaseHelper.instance.getPedidos();
  if (!mounted) return;
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Pedidos: ${pedidos.length}'),
      content: SizedBox(
        width: double.maxFinite,
        child: pedidos.isEmpty
          ? const Text('No hay pedidos registrados')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: pedidos.length,
                itemBuilder: (context, index) {
                  var p = pedidos[index];
                  return ListTile(
                    title: Text('Folio: ${p['folio']}'),
                    subtitle: Text('Vol: ${p['volante']} | Carp: ${p['carpeta']} | Mesa: ${p['mesa']}'),
                    leading: const Icon(Icons.send, color: Colors.blue),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await _subirListaNube('PEDIDOS');
          },
          child: const Text('SUBIR A DRIVE'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CERRAR')
        ),
      ],
    ),
  );
}

void _mostrarListaRecibidos() async {
  List<Map<String, dynamic>> recibidos = await DatabaseHelper.instance.getRecibidos();
  if (!mounted) return;
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Recibidos: ${recibidos.length}'),
      content: SizedBox(
        width: double.maxFinite,
        child: recibidos.isEmpty
          ? const Text('No hay carpetas recibidas')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: recibidos.length,
                itemBuilder: (context, index) {
                  var r = recibidos[index];
                  return ListTile(
                    title: Text('Folio: ${r['folio']}'),
                    subtitle: Text('Vol: ${r['volante']} | Carp: ${r['carpeta']} | Mesa: ${r['mesa']}'),
                    leading: const Icon(Icons.inbox, color: Colors.green),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await _subirListaNube('RECIBIDOS');
          },
          child: const Text('SUBIR A DRIVE'),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CERRAR')),
      ],
    ),
  );
}

  void _mostrarDetallesVolante(Map<String, dynamic> carpeta, String volante) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Volante: $volante'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: listaCampos.map((campo) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    campo.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)
                  ),
                  Text(
                    carpeta[campo]?.toString()?? 'Sin datos',
                    style: const TextStyle(fontSize: 14, color: Colors.black87)
                  ),
                  const Divider(height: 12),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await _subirVolanteNube(_completarCampos(carpeta), volante, 'csv');
          },
          child: const Text('SUBIR CSV A DRIVE'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await _subirVolanteNube(_completarCampos(carpeta), volante, 'excel');
          },
          child: const Text('SUBIR EXCEL A DRIVE'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CERRAR'),
        ),
      ],
    ),
  );
}

void _dialogoPedidos() {
  String volante = '', carpeta = '', folio = '', mesa = '';
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Nuevo Pedido'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(decoration: const InputDecoration(labelText: 'Volante'), onChanged: (v) => volante = v),
            TextField(decoration: const InputDecoration(labelText: 'Carpeta'), onChanged: (v) => carpeta = v),
            TextField(decoration: const InputDecoration(labelText: 'Folio'), onChanged: (v) => folio = v),
            TextField(decoration: const InputDecoration(labelText: 'Mesa'), onChanged: (v) => mesa = v),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
        TextButton(
          onPressed: () async {
            if (folio.isEmpty || volante.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Folio y Volante obligatorios')));
              return;
            }
            await DatabaseHelper.instance.addPedido(folio, volante, carpeta, mesa);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pedido $folio guardado')));
          },
          child: const Text('GUARDAR'),
        ),
      ],
    ),
  );
}

void _dialogoRecibidos() {
  String folio = '';
  String volante = '', carpeta = '', mesa = '';
  bool encontrado = false;

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Recibir Carpeta'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Folio'),
                  onChanged: (v) async {
                    folio = v;
                    var pedido = await DatabaseHelper.instance.getPedidoPorFolio(v);
                    setDialogState(() {
                      if (pedido!= null) {
                        volante = pedido['volante'];
                        carpeta = pedido['carpeta'];
                        mesa = pedido['mesa'];
                        encontrado = true;
                      } else {
                        volante = carpeta = mesa = '';
                        encontrado = false;
                      }
                    });
                  },
                ),
                const SizedBox(height: 10),
                if (encontrado)...[
                  Text('Volante: $volante', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Carpeta: $carpeta'),
                  Text('Mesa: $mesa'),
                ] else if (folio.isNotEmpty)
                  const Text('Carpeta no pedida', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
            TextButton(
              onPressed: encontrado? () async {
                await DatabaseHelper.instance.addRecibido(folio, volante, carpeta, mesa);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Folio $folio recibido')));
              } : null,
              child: const Text('RECIBIR'),
            ),
          ],
        ),
      );
    },
  );
}

void _dialogoPendientes() async {
  List<Map<String, dynamic>> pendientes = await DatabaseHelper.instance.getPendientes();
  if (!mounted) return;
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Pendientes: ${pendientes.length}'),
      content: SizedBox(
        width: double.maxFinite,
        child: pendientes.isEmpty
          ? const Text('No hay pendientes. Todo recibido ✅')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: pendientes.length,
                itemBuilder: (context, index) {
                  var p = pendientes[index];
                  return ListTile(
                    title: Text('Folio: ${p['folio']}'),
                    subtitle: Text('Vol: ${p['volante']} | Carp: ${p['carpeta']} | Mesa: ${p['mesa']}'),
                    leading: const Icon(Icons.warning, color: Colors.orange),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await _subirListaNube('PENDIENTES');
          },
          child: const Text('SUBIR A DRIVE'),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CERRAR')),
      ],
    ),
  );
}

Map<String, dynamic> _completarCampos(Map<String, dynamic> carpeta) {
  Map<String, dynamic> completo = {};
  for (var campo in listaCampos) {
    completo[campo] = carpeta[campo]?? 'Sin datos';
  }
  return completo;
}

Future<void> _exportarExcel(Map<String, dynamic> datos, String volante) async {
  var excel = Excel.createExcel();
  Sheet sheet = excel['Volante_$volante'];

  sheet.appendRow([
    TextCellValue('CAMPO'),
    TextCellValue('VALOR')
  ]);

  datos.forEach((key, value) {
    sheet.appendRow([
      TextCellValue(key),
      TextCellValue(value?.toString()?? 'Sin datos')
    ]);
  });

  final directory = await getApplicationDocumentsDirectory();
  String path = '${directory.path}/Volante_$volante.xlsx';

  List<int>? fileBytes = excel.save();
  if (fileBytes!= null) {
    File(path)
     ..createSync(recursive: true)
     ..writeAsBytesSync(fileBytes);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Excel guardado en: $path')),
    );
  }
}

Future<void> _exportarCsv(Map<String, dynamic> datos, String volante) async {
  try {
    List<List<String>> rows = [];
    rows.add(['CAMPO', 'VALOR']);
    datos.forEach((key, value) {
      rows.add([key, value?.toString()?? 'Sin datos']);
    });

    String csv = const ListToCsvConverter().convert(rows);

    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/Volante_$volante.csv';
    final file = File(path);
    await file.writeAsString(csv);

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('CSV guardado en: $path')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al exportar CSV: $e')),
    );
  }
}

Future<void> _subirVolanteNube(Map<String, dynamic> datos, String volante, String tipo) async {
  try {
    List<List<String>> rows = [['CAMPO', 'VALOR']];
    datos.forEach((key, value) => rows.add([key, value?.toString()?? 'Sin datos']));
    String contenido = const ListToCsvConverter().convert(rows);

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subiendo a Drive...')));
    await DriveHelper.subirArchivo('Volante_${volante}_$tipo.csv', contenido, 'text/csv');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Volante $volante subido a Google Drive')));
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
  }
}

Future<void> _subirListaNube(String nombreLista) async {
  try {
    List<Map<String, dynamic>> datos;
    if (nombreLista == 'PEDIDOS') datos = await DatabaseHelper.instance.getPedidos();
    else if (nombreLista == 'RECIBIDOS') datos = await DatabaseHelper.instance.getRecibidos();
    else datos = await DatabaseHelper.instance.getPendientes();

    if (datos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No hay datos en $nombreLista')));
      return;
    }

    List<List<String>> rows = [['FOLIO', 'VOLANTE', 'CARPETA', 'MESA', 'FECHA']];
    for (var p in datos) {
      rows.add([p['folio'], p['volante'], p['carpeta'], p['mesa'], p['fecha']]);
    }
    String contenido = const ListToCsvConverter().convert(rows);

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subiendo a Drive...')));
    await DriveHelper.subirArchivo('${nombreLista}_${DateTime.now().millisecondsSinceEpoch}.csv', contenido, 'text/csv');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$nombreLista subido a Drive')));
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
  }
}

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
            onSelected: (value) async {
              if (value == 'Pedidos') _dialogoPedidos();
              if (value == 'Recibidos') _dialogoRecibidos();
              if (value == 'Pendientes') _dialogoPendientes();
              // ▼▼▼ AGREGA ESTA LÍNEA ▼▼▼
              if (value == 'Plantillas') await _descargarPlantillas(context);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'Pedidos', child: Text('Pedidos')),
              const PopupMenuItem(value: 'Recibidos', child: Text('Recibidos')),
              const PopupMenuItem(value: 'Pendientes', child: Text('Pendientes')),
              // ▼▼▼ AGREGA ESTA LÍNEA ▼▼▼
              const PopupMenuItem(value: 'Plantillas', child: Text('Plantillas')),
            ],
          ),
        ],
      ),
      body: mostrarCamara? const ScannerScreen() : const BeastieHome(),
    );
  }
}

class BeastieHome extends StatefulWidget {
  const BeastieHome({super.key});

  @override
  State<BeastieHome> createState() => _BeastieHomeState();
}

class _BeastieHomeState extends State<BeastieHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inicializarDatosPostLogin();
    });
  }

  Future<void> _inicializarDatosPostLogin() async {
  }

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
