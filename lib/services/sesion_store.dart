import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/usuario_sesion.dart';

/// Guarda la sesión del usuario para que sobreviva a recargar la página.
/// Solo sirve para la interfaz (mostrar/ocultar botones); los permisos reales
/// los valida siempre el servidor.
class SesionStore {
  SesionStore._();

  static const String _clave = 'usuario_sesion';

  /// Sesión en memoria, disponible de forma síncrona tras [cargar].
  static UsuarioSesion? actual;

  static Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final texto = prefs.getString(_clave);
      if (texto == null) return;
      final json = jsonDecode(texto) as Map<String, dynamic>;
      actual = UsuarioSesion(
        nombre: json['nombre']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        provider: json['provider']?.toString() ?? 'password',
        rol: json['rol'] == 'Administrador' ? 'Administrador' : 'Usuario',
      );
    } catch (_) {
      actual = null;
    }
  }

  static Future<void> guardar(UsuarioSesion sesion) async {
    actual = sesion;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _clave,
        jsonEncode({
          'nombre': sesion.nombre,
          'email': sesion.email,
          'provider': sesion.provider,
          'rol': sesion.rol,
        }),
      );
    } catch (_) {
      // Si no se puede persistir, la sesión sigue válida en memoria.
    }
  }

  static Future<void> borrar() async {
    actual = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_clave);
    } catch (_) {}
  }
}
