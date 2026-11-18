import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/cliente.dart';
import '../models/usuario_sesion.dart';
import 'api_http_client_factory.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? createApiHttpClient();

  static const String oauthBaseUrl = String.fromEnvironment(
    'OAUTH_BASE_URL',
    defaultValue: 'https://float-egotism-dispersed.ngrok-free.dev',
  );

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: oauthBaseUrl,
  );

  final http.Client _client;
  static String? _nativeSessionCookie;

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };

  Map<String, String> get _requestHeaders => {
    ..._headers,
    if (!kIsWeb && _nativeSessionCookie != null)
      'Cookie': _nativeSessionCookie!,
  };

  static void limpiarSesionLocal() {
    _nativeSessionCookie = null;
  }

  void _guardarCookieSesion(http.Response response) {
    if (kIsWeb) return;
    final setCookie = response.headers['set-cookie'];
    if (setCookie == null) return;
    final cookie = setCookie.split(';').first.trim();
    if (cookie.startsWith('session=')) _nativeSessionCookie = cookie;
  }

  void close() => _client.close();

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<UsuarioSesion> iniciarSesion({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      _uri('/api/auth/login'),
      headers: _requestHeaders,
      body: jsonEncode({'email': email.trim(), 'password': password}),
    );
    if (response.statusCode == 200) _guardarCookieSesion(response);
    final data = _decode(response);
    if (response.statusCode != 200 || data is! Map<String, dynamic>) {
      _throwApiError(response, data);
    }
    return UsuarioSesion.fromJson(data);
  }

  Future<UsuarioSesion> registrarUsuario({
    required String nombre,
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      _uri('/api/auth/register'),
      headers: _requestHeaders,
      body: jsonEncode({
        'nombre': nombre.trim(),
        'email': email.trim(),
        'password': password,
      }),
    );
    if (response.statusCode == 201) _guardarCookieSesion(response);
    final data = _decode(response);
    if (response.statusCode != 201 || data is! Map<String, dynamic>) {
      _throwApiError(response, data);
    }
    return UsuarioSesion.fromJson(data);
  }

  Future<List<Cliente>> obtenerClientes() async {
    // El parámetro "_" evita que el navegador/ngrok devuelvan una lista en caché.
    final response = await _client.get(
      _uri('/api/clientes?_=${DateTime.now().millisecondsSinceEpoch}'),
      headers: _requestHeaders,
    );
    final data = _decode(response);
    if (response.statusCode != 200) _throwApiError(response, data);
    if (data is! List) {
      throw const ApiException(
        'La respuesta de clientes no tiene un formato válido.',
      );
    }
    return data
        .map((item) => Cliente.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  /// Crea el cliente. Devuelve el cliente creado si la API lo incluye en la
  /// respuesta (con su id), o null si no.
  Future<Cliente?> crearCliente(Cliente cliente) async {
    final response = await _client.post(
      _uri('/api/clientes'),
      headers: _requestHeaders,
      body: jsonEncode(cliente.toJson()),
    );
    final data = _decode(response);
    if (response.statusCode != 201) {
      _throwApiError(response, data, conflictoEsDuplicado: true);
    }
    if (data is Map) {
      final mapa = Map<String, dynamic>.from(data);
      final interno = mapa['cliente'] ?? mapa['data'];
      final candidato = interno is Map
          ? Map<String, dynamic>.from(interno)
          : mapa;
      if (candidato['clienteId'] != null && candidato['cedula'] != null) {
        return Cliente.fromJson(candidato);
      }
    }
    return null;
  }

  Future<void> actualizarCliente(Cliente cliente) async {
    final response = await _client.put(
      _uri('/api/clientes'),
      headers: _requestHeaders,
      body: jsonEncode(cliente.toJson(incluirIdentificadores: true)),
    );
    if (response.statusCode != 200) {
      _throwApiError(response, _decode(response));
    }
  }

  Future<void> eliminarCliente(int id) async {
    final response = await _client.delete(
      _uri('/api/clientes/$id'),
      headers: _requestHeaders,
    );
    if (response.statusCode != 200) {
      _throwApiError(response, _decode(response));
    }
  }

  Future<Map<String, dynamic>?> probarConexion() async {
    final response = await _client.get(
      _uri('/test-db'),
      headers: _requestHeaders,
    );
    final data = _decode(response);
    if (response.statusCode != 200) _throwApiError(response, data);
    return data is Map<String, dynamic> ? data : null;
  }

  dynamic _decode(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      return null;
    }
  }

  static const String mensajeCedulaDuplicada =
      'Ya existe un cliente registrado con esta cédula.';

  Never _throwApiError(
    http.Response response,
    dynamic data, {
    bool conflictoEsDuplicado = false,
  }) {
    final message = data is Map
        ? (data['message'] ?? data['error'] ?? data['detail'])?.toString()
        : null;
    final pareceDuplicado =
        message != null &&
        RegExp(
          r'duplic|unique|ya existe|ya est[aá] registrad|c[eé]dula',
          caseSensitive: false,
        ).hasMatch(message);
    if (pareceDuplicado ||
        (response.statusCode == 409 && conflictoEsDuplicado)) {
      throw ApiException(
        mensajeCedulaDuplicada,
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode == 409) {
      throw ApiException(
        'Este cliente cambió en el servidor. Recarga la lista antes de editarlo.',
        statusCode: response.statusCode,
      );
    }
    throw ApiException(
      message ?? 'Error de conexión con la API (${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }
}
