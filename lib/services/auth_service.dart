import 'package:url_launcher/url_launcher.dart';

import '../models/usuario_sesion.dart';
import 'api_service.dart';

class AuthService {
  Future<UsuarioSesion> iniciarSesion({
    required String email,
    required String password,
  }) async {
    final api = ApiService();
    try {
      return await api.iniciarSesion(email: email, password: password);
    } finally {
      api.close();
    }
  }

  Future<UsuarioSesion> registrarUsuario({
    required String nombre,
    required String email,
    required String password,
  }) async {
    final api = ApiService();
    try {
      return await api.registrarUsuario(
        nombre: nombre,
        email: email,
        password: password,
      );
    } finally {
      api.close();
    }
  }

  Future<void> iniciarConGoogle() => _abrir('/login_google');

  Future<void> iniciarConFacebook() => _abrir('/login_facebook');

  Future<void> iniciarConInstagram() => _abrir('/login_instagram');

  Future<void> cerrarSesionWeb() {
    ApiService.limpiarSesionLocal();
    return _abrir('/logout');
  }

  Future<void> _abrir(String path) async {
    final uri = Uri.parse('${ApiService.oauthBaseUrl}$path');
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_self',
    );
    if (!opened) {
      throw Exception('No se pudo abrir la página de autenticación.');
    }
  }

  UsuarioSesion? leerSesionDesdeUrl() {
    final params = Uri.base.queryParameters;

    if (params.containsKey('error')) {
      throw Exception('Error en autenticación social: ${params['error']}');
    }

    final usuario = params['usuario'];
    final email = params['email'];
    final provider = params['provider'] ?? 'oauth';
    final rol = params['rol'] == 'Administrador' ? 'Administrador' : 'Usuario';

    if (usuario != null &&
        usuario.isNotEmpty &&
        email != null &&
        email.isNotEmpty) {
      return UsuarioSesion(
        nombre: usuario,
        email: email,
        provider: provider,
        rol: rol,
      );
    }
    return null;
  }
}
