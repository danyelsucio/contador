import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class DriveHelper {
  static final _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
    // 👑 PEGA AQUÍ EL ID DE "Contador Fiscalis Android"
    clientId: '992297094453-orpa1aqaac72j19fu1u8bncgambr4ivj.apps.googleusercontent.com', 
  );

  static Future<drive.DriveApi?> getDriveApi() async {
    GoogleSignInAccount? account = await _googleSignIn.signInSilently();
    account ??= await _googleSignIn.signIn();
    
    if (account == null) return null;
    
    final authHeaders = await account.authHeaders;
    final authenticateClient = GoogleAuthClient(authHeaders);
    return drive.DriveApi(authenticateClient);
  }

  static Future<void> subirArchivo(String nombre, String contenido, String mimeType) async {
    final driveApi = await getDriveApi();
    if (driveApi == null) throw Exception('Login cancelado o sin permisos de Drive');

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
