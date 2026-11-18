class UsuarioSesion {
  const UsuarioSesion({
    required this.nombre,
    required this.email,
    required this.provider,
    required this.rol,
  });

  final String nombre;
  final String email;
  final String provider;
  final String rol;

  factory UsuarioSesion.fromJson(
    Map<String, dynamic> json, {
    String provider = 'password',
  }) {
    return UsuarioSesion(
      nombre: json['usuario']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      provider: provider,
      rol: json['rol'] == 'Administrador' ? 'Administrador' : 'Usuario',
    );
  }
}
