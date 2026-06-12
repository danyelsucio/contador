import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

class DriveHelper {
  static final _googleSignIn = GoogleSignIn.standard(scopes: [drive.DriveApi.driveFileScope]);

  static Future<drive.DriveApi?> getDriveApi() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null;
    
    final authHeaders = await account.authHeaders;
    final authenticateClient = GoogleAuthClient(authHeaders);
    return drive.DriveApi(authenticateClient);
  }

  static Future<void> subirArchivo(String nombre, String contenido, String mimeType) async {
    final driveApi = await getDriveApi();
    if (driveApi == null) throw Exception('Login cancelado');

    final media = drive.Media(Stream.value(contenido.codeUnits), contenido.length);
    final driveFile = drive.File()..name = nombre;
    
    await driveApi.files.create(driveFile, uploadMedia: media);
  }
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();
  GoogleAuthClient(this._headers);
  
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}
