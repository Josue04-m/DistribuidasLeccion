class Cliente {
  const Cliente({
    this.clienteId,
    required this.cedula,
    required this.nombre,
    required this.apellido,
    this.telefono,
    this.direccion,
    this.correo,
    this.fechaRegistro,
    this.estado = true,
    this.rowVer,
  });

  final int? clienteId;
  final String cedula;
  final String nombre;
  final String apellido;
  final String? telefono;
  final String? direccion;
  final String? correo;
  final DateTime? fechaRegistro;
  final bool estado;
  final String? rowVer;

  factory Cliente.fromJson(Map<String, dynamic> json) => Cliente(
    clienteId: (json['clienteId'] as num?)?.toInt(),
    cedula: json['cedula']?.toString() ?? '',
    nombre: json['nombre']?.toString() ?? '',
    apellido: json['apellido']?.toString() ?? '',
    telefono: json['telefono']?.toString(),
    direccion: json['direccion']?.toString(),
    correo: json['correo']?.toString(),
    fechaRegistro: DateTime.tryParse(json['fechaRegistro']?.toString() ?? ''),
    estado: json['estado'] as bool? ?? true,
    rowVer: json['rowVer']?.toString(),
  );

  Map<String, dynamic> toJson({bool incluirIdentificadores = false}) => {
    if (incluirIdentificadores && clienteId != null) 'clienteId': clienteId,
    if (incluirIdentificadores && rowVer != null) 'rowVer': rowVer,
    'cedula': cedula,
    'nombre': nombre,
    'apellido': apellido,
    'telefono': telefono,
    'direccion': direccion,
    'correo': correo,
  };
}
