import 'package:flutter/material.dart';

import '../models/cliente.dart';
import '../utils/validadores.dart';

class ClienteFormPage extends StatefulWidget {
  const ClienteFormPage({
    super.key,
    this.cliente,
    this.cedulasExistentes = const {},
  });

  final Cliente? cliente;

  /// Cédulas de otros clientes ya registrados (para avisar antes de enviar).
  final Set<String> cedulasExistentes;

  @override
  State<ClienteFormPage> createState() => _ClienteFormPageState();
}

class _ClienteFormPageState extends State<ClienteFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _cedula;
  late final TextEditingController _nombre;
  late final TextEditingController _apellido;
  late final TextEditingController _telefono;
  late final TextEditingController _direccion;
  late final TextEditingController _correo;

  @override
  void initState() {
    super.initState();
    final cliente = widget.cliente;
    _cedula = TextEditingController(text: cliente?.cedula ?? '');
    _nombre = TextEditingController(text: cliente?.nombre ?? '');
    _apellido = TextEditingController(text: cliente?.apellido ?? '');
    _telefono = TextEditingController(text: cliente?.telefono ?? '');
    _direccion = TextEditingController(text: cliente?.direccion ?? '');
    _correo = TextEditingController(text: cliente?.correo ?? '');
  }

  @override
  void dispose() {
    _cedula.dispose();
    _nombre.dispose();
    _apellido.dispose();
    _telefono.dispose();
    _direccion.dispose();
    _correo.dispose();
    super.dispose();
  }

  bool _guardado = false;

  bool get _hayCambios {
    final c = widget.cliente;
    return _cedula.text.trim() != (c?.cedula ?? '') ||
        Validadores.normalizar(_nombre.text) != (c?.nombre ?? '') ||
        Validadores.normalizar(_apellido.text) != (c?.apellido ?? '') ||
        Validadores.normalizar(_telefono.text) != (c?.telefono ?? '') ||
        Validadores.normalizar(_direccion.text) != (c?.direccion ?? '') ||
        Validadores.normalizar(_correo.text) != (c?.correo ?? '');
  }

  String? _validarCedula(String? valor) {
    final error = Validadores.cedula(valor);
    if (error != null) return error;
    if (widget.cedulasExistentes.contains(valor!.trim())) {
      return 'Ya existe un cliente registrado con esta cédula';
    }
    return null;
  }

  Future<bool> _confirmarDescartar() async {
    if (_guardado || !_hayCambios) return true;
    final salir = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('¿Descartar cambios?'),
        content: const Text('Tienes datos sin guardar. Si sales, se perderán.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Seguir editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return salir == true;
  }

  Future<void> _cancelar() async {
    if (await _confirmarDescartar() && mounted) Navigator.pop(context);
  }

  String? _opcional(String texto) {
    final limpio = Validadores.normalizar(texto);
    return limpio.isEmpty ? null : limpio;
  }

  Future<bool> _confirmarGuardado() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        final esquema = Theme.of(context).colorScheme;
        return AlertDialog(
          icon: Icon(Icons.help_outline, size: 32, color: esquema.primary),
          title: const Text('Guardar cambios', textAlign: TextAlign.center),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(
              '¿Deseas guardar los cambios de '
              '${Validadores.normalizar(_nombre.text)} '
              '${Validadores.normalizar(_apellido.text)}?',
              textAlign: TextAlign.center,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(120, 44)),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
    return ok == true;
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    // Al editar se confirma aquí, con el formulario todavía abierto.
    if (widget.cliente != null && !await _confirmarGuardado()) return;
    if (!mounted) return;
    final cliente = widget.cliente;
    _guardado = true;
    Navigator.pop(
      context,
      Cliente(
        clienteId: cliente?.clienteId,
        cedula: _cedula.text.trim(),
        nombre: Validadores.normalizar(_nombre.text),
        apellido: Validadores.normalizar(_apellido.text),
        telefono: _opcional(_telefono.text),
        direccion: _opcional(_direccion.text),
        correo: _opcional(_correo.text)?.toLowerCase(),
        rowVer: cliente?.rowVer,
      ),
    );
  }

  /// Dos campos en fila si hay espacio; uno bajo otro en pantallas estrechas.
  Widget _fila(Widget a, Widget b) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 480) {
          return Column(children: [a, const SizedBox(height: 16), b]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: 16),
            Expanded(child: b),
          ],
        );
      },
    );
  }

  Widget _seccion(IconData icono, String titulo, List<Widget> hijos) {
    final tema = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tema.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icono, size: 20, color: tema.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Text(
                  titulo,
                  style: tema.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...hijos,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editar = widget.cliente != null;
    final tema = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmarDescartar()) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Volver',
            icon: const Icon(Icons.arrow_back),
            onPressed: _cancelar,
          ),
          title: Text(
            editar ? 'Editar cliente' : 'Nuevo cliente',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _seccion(Icons.badge_outlined, 'Datos personales', [
                      TextFormField(
                        controller: _cedula,
                        decoration: const InputDecoration(
                          labelText: 'Cédula *',
                          hintText: '10 dígitos',
                          prefixIcon: Icon(Icons.badge_outlined),
                          counterText: '',
                        ),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        maxLength: 10,
                        inputFormatters: Validadores.soloDigitos,
                        validator: _validarCedula,
                      ),
                      const SizedBox(height: 16),
                      _fila(
                        TextFormField(
                          controller: _nombre,
                          decoration: const InputDecoration(
                            labelText: 'Nombre *',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          inputFormatters: Validadores.conLimite(
                            Validadores.soloLetras,
                            50,
                          ),
                          validator: (v) =>
                              Validadores.nombre(v, campo: 'El nombre'),
                        ),
                        TextFormField(
                          controller: _apellido,
                          decoration: const InputDecoration(
                            labelText: 'Apellido *',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          inputFormatters: Validadores.conLimite(
                            Validadores.soloLetras,
                            50,
                          ),
                          validator: (v) =>
                              Validadores.nombre(v, campo: 'El apellido'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _seccion(Icons.contact_phone_outlined, 'Contacto', [
                      _fila(
                        TextFormField(
                          controller: _telefono,
                          decoration: const InputDecoration(
                            labelText: 'Teléfono',
                            hintText: '0991234567',
                            prefixIcon: Icon(Icons.phone_outlined),
                            counterText: '',
                          ),
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          maxLength: 10,
                          inputFormatters: Validadores.soloDigitos,
                          validator: Validadores.telefono,
                        ),
                        TextFormField(
                          controller: _correo,
                          decoration: const InputDecoration(
                            labelText: 'Correo',
                            hintText: 'nombre@dominio.com',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          inputFormatters: Validadores.conLimite(
                            Validadores.correo,
                            100,
                          ),
                          validator: (v) => Validadores.correoElectronico(
                            v,
                            obligatorio: false,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _direccion,
                        decoration: const InputDecoration(
                          labelText: 'Dirección',
                          prefixIcon: Icon(Icons.home_outlined),
                        ),
                        textInputAction: TextInputAction.done,
                        inputFormatters: Validadores.conLimite(
                          Validadores.direccion,
                          100,
                        ),
                        validator: Validadores.direccionOpcional,
                        onFieldSubmitted: (_) => _guardar(),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Text(
                      '* Campos obligatorios',
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, c) {
                        final guardar = FilledButton.icon(
                          onPressed: _guardar,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(
                            editar ? 'Guardar cambios' : 'Guardar cliente',
                          ),
                        );
                        final cancelar = OutlinedButton(
                          onPressed: _cancelar,
                          child: const Text('Cancelar'),
                        );
                        if (c.maxWidth < 480) {
                          return Column(
                            children: [
                              guardar,
                              const SizedBox(height: 10),
                              cancelar,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: cancelar),
                            const SizedBox(width: 14),
                            Expanded(flex: 2, child: guardar),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
