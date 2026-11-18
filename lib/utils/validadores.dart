import 'package:flutter/services.dart';

/// Filtro que solo actúa cuando el texto nuevo trae caracteres no permitidos.
/// Si el texto ya es válido (por ejemplo al borrar) lo devuelve sin tocarlo.
class _Permitir extends TextInputFormatter {
  _Permitir(this.patron);

  final RegExp patron;

  String _filtrar(String texto) =>
      texto.runes.map(String.fromCharCode).where(patron.hasMatch).join();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final texto = newValue.text;
    if (texto.isEmpty) return newValue;
    final limpio = _filtrar(texto);
    if (limpio.length == texto.length) return newValue;
    final cursor = newValue.selection.baseOffset.clamp(0, texto.length);
    final antes = _filtrar(texto.substring(0, cursor));
    return TextEditingValue(
      text: limpio,
      selection: TextSelection.collapsed(offset: antes.length),
    );
  }
}

class Validadores {
  Validadores._();
  static final List<TextInputFormatter> soloLetras = [
    _Permitir(RegExp(r"[A-Za-zÁÉÍÓÚÜÑáéíóúüñ\s'\-]")),
  ];

  static final List<TextInputFormatter> soloDigitos = [
    _Permitir(RegExp(r'[0-9]')),
  ];

  static final List<TextInputFormatter> direccion = [
    _Permitir(RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ0-9\s.,#\-/°]')),
  ];

  /// Correo: sin espacios ni emojis.
  static final List<TextInputFormatter> correo = [
    _Permitir(RegExp(r"[A-Za-z0-9@._+\-]")),
  ];

  /// Contraseña: ASCII imprimible, sin espacios ni emojis.
  static final List<TextInputFormatter> password = [
    _Permitir(RegExp(r'[\x21-\x7E]')),
  ];

  static List<TextInputFormatter> conLimite(
    List<TextInputFormatter> base,
    int max,
  ) => [...base, LengthLimitingTextInputFormatter(max)];

  // ---------- Validadores ----------

  static final RegExp _nombreRegExp = RegExp(
    r"^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+(?:[ '\-][A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+)*$",
  );
  static final RegExp _correoRegExp = RegExp(
    r'^[A-Za-z0-9._+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$',
  );
  static final RegExp _direccionRegExp = RegExp(
    r'^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ0-9\s.,#\-/°]+$',
  );

  /// Nombre o apellido: solo letras, 2 a 50 caracteres.
  static String? nombre(String? valor, {String campo = 'El nombre'}) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return '$campo es obligatorio';
    if (texto.length < 2) return '$campo debe tener al menos 2 letras';
    if (texto.length > 50) return '$campo no puede superar 50 caracteres';
    if (!_nombreRegExp.hasMatch(texto)) {
      return '$campo solo admite letras (sin números, símbolos ni emojis)';
    }
    return null;
  }

  /// Cédula: solo se exige que tenga exactamente 10 dígitos.
  static String? cedula(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return 'La cédula es obligatoria';
    if (!RegExp(r'^\d+$').hasMatch(texto)) {
      return 'La cédula solo admite números';
    }
    if (texto.length != 10) return 'La cédula debe tener 10 dígitos';
    return null;
  }

  /// Teléfono (opcional): 9 dígitos (fijo) o 10 dígitos (celular), inicia en 0.
  static String? telefono(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return null;
    if (!RegExp(r'^\d+$').hasMatch(texto)) {
      return 'El teléfono solo admite números';
    }
    if (!texto.startsWith('0')) return 'El teléfono debe iniciar con 0';
    if (texto.length != 9 && texto.length != 10) {
      return 'Debe tener 9 dígitos (fijo) o 10 (celular)';
    }
    if (texto.length == 10 && !texto.startsWith('09')) {
      return 'Un celular debe iniciar con 09';
    }
    return null;
  }

  /// Dirección (opcional): 5 a 100 caracteres sin símbolos raros ni emojis.
  static String? direccionOpcional(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return null;
    if (texto.length < 5) {
      return 'La dirección debe tener al menos 5 caracteres';
    }
    if (texto.length > 100) {
      return 'La dirección no puede superar 100 caracteres';
    }
    if (!_direccionRegExp.hasMatch(texto)) {
      return 'La dirección contiene caracteres no permitidos';
    }
    return null;
  }

  /// Correo. Si [obligatorio] es false, acepta vacío.
  static String? correoElectronico(String? valor, {bool obligatorio = true}) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return obligatorio ? 'El correo es obligatorio' : null;
    if (texto.length > 100) return 'El correo no puede superar 100 caracteres';
    if (!_correoRegExp.hasMatch(texto) || texto.contains('..')) {
      return 'Ingresa un correo válido (ej. nombre@dominio.com)';
    }
    return null;
  }

  static String? contrasena(String? valor, {required bool registro}) {
    final texto = valor ?? '';
    if (texto.isEmpty) return 'Ingresa tu contraseña';
    if (!registro) return null;
    if (texto.length < 8) return 'Debe tener al menos 8 caracteres';
    if (texto.length > 64) return 'No puede superar 64 caracteres';
    if (texto.contains(RegExp(r'\s'))) return 'No puede contener espacios';
    if (!texto.contains(RegExp(r'[A-Za-z]'))) return 'Debe incluir una letra';
    if (!texto.contains(RegExp(r'\d'))) return 'Debe incluir un número';
    return null;
  }

  static String normalizar(String valor) =>
      valor.trim().replaceAll(RegExp(r'\s+'), ' ');
}
