import 'package:flutter/material.dart';

import '../models/cliente.dart';
import '../models/usuario_sesion.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/sesion_store.dart';
import 'cliente_form_page.dart';

class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  final ApiService _api = ApiService();
  final AuthService _auth = AuthService();
  late Future<List<Cliente>> _clientes;
  List<Cliente> _ultimos = const [];

  UsuarioSesion? get _usuario {
    final sesion = ModalRoute.of(context)?.settings.arguments;
    // Tras recargar la página los argumentos de la ruta se pierden, por eso
    // se usa la sesión guardada como respaldo.
    return sesion is UsuarioSesion ? sesion : SesionStore.actual;
  }

  bool get _esAdministrador => _usuario?.rol == 'Administrador';

  Future<List<Cliente>> _cargar() {
    return _api
        .obtenerClientes()
        .then((lista) {
          _ultimos = lista;
          return lista;
        })
        .catchError((Object error) {
          if (error is ApiException && error.statusCode == 401) {
            // La sesión del servidor expiró: volver al login.
            SesionStore.borrar();
            if (mounted) Navigator.pushReplacementNamed(context, '/');
          }
          throw error;
        });
  }

  @override
  void initState() {
    super.initState();
    _clientes = _cargar();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<bool> _confirmar({
    required String titulo,
    required String mensaje,
    required String accion,
    bool peligroso = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        final esquema = Theme.of(context).colorScheme;
        return AlertDialog(
          icon: Icon(
            peligroso ? Icons.delete_forever_outlined : Icons.help_outline,
            size: 32,
            color: peligroso ? esquema.error : esquema.primary,
          ),
          title: Text(titulo, textAlign: TextAlign.center),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(mensaje, textAlign: TextAlign.center),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(120, 44)),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(120, 44),
                backgroundColor: peligroso ? esquema.error : null,
                foregroundColor: peligroso ? esquema.onError : null,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(accion),
            ),
          ],
        );
      },
    );
    return ok == true;
  }

  Future<void> _cerrarSesion() async {
    final ok = await _confirmar(
      titulo: 'Cerrar sesión',
      mensaje: '¿Seguro que deseas cerrar tu sesión?',
      accion: 'Cerrar sesión',
    );
    if (!ok) return;
    try {
      await SesionStore.borrar();
      await _auth.cerrarSesionWeb();
    } catch (error) {
      if (mounted) _mensaje(error.toString());
    }
  }

  Future<void> _recargar() async {
    final futuro = _cargar();
    setState(() {
      _clientes = futuro;
    });
    try {
      await futuro;
    } catch (_) {
      // FutureBuilder muestra el error y permite reintentar.
    }
  }

  void _mensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _abrirFormulario({Cliente? cliente}) async {
    if (!_esAdministrador) return;
    final cedulasOtros = {
      for (final c in _ultimos)
        if (c.clienteId != cliente?.clienteId) c.cedula,
    };
    final resultado = await Navigator.push<Cliente>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ClienteFormPage(cliente: cliente, cedulasExistentes: cedulasOtros),
      ),
    );
    if (resultado == null || !mounted) return;
    // La confirmación de edición ya se pidió dentro del formulario.
    try {
      if (cliente == null) {
        final creado = await _api.crearCliente(resultado);
        if (!mounted) return;
        final nuevo = creado ?? resultado;
        // Se muestra al instante, sin esperar a que el servidor lo liste.
        _mostrarLocal([nuevo, ..._ultimos]);
        _mensaje('Cliente creado.');
        await _sincronizar(
          (lista) => lista.any((c) => c.cedula == nuevo.cedula),
        );
      } else {
        await _api.actualizarCliente(resultado);
        if (!mounted) return;
        _mostrarLocal([
          for (final c in _ultimos)
            c.clienteId == cliente.clienteId ? resultado : c,
        ]);
        _mensaje('Cliente actualizado.');
        await _sincronizar(
          (lista) => lista.any(
            (c) =>
                c.clienteId == cliente.clienteId &&
                c.nombre == resultado.nombre &&
                c.apellido == resultado.apellido &&
                c.cedula == resultado.cedula,
          ),
        );
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      _mensaje(error.message);
      await _recargar();
    } catch (error) {
      if (!mounted) return;
      _mensaje(error.toString());
      await _recargar();
    }
  }

  /// Muestra [lista] de inmediato como estado actual de la pantalla.
  void _mostrarLocal(List<Cliente> lista) {
    _ultimos = lista;
    setState(() {
      _clientes = Future.value(lista);
    });
  }

  /// Consulta al servidor y adopta su lista solo cuando ya refleja el cambio
  /// ([refleja] es true). Si el servidor aún devuelve datos viejos, reintenta
  /// y, de no cambiar, conserva lo que ya se muestra.
  Future<void> _sincronizar(bool Function(List<Cliente>) refleja) async {
    for (var intento = 0; intento < 4; intento++) {
      if (intento > 0) await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      try {
        final lista = await _api.obtenerClientes();
        if (!mounted) return;
        if (refleja(lista)) {
          _mostrarLocal(lista);
          return;
        }
      } catch (_) {
        // Se conserva la lista local; el usuario puede recargar la página.
        return;
      }
    }
  }

  Future<void> _eliminar(Cliente cliente) async {
    if (!_esAdministrador) return;
    final confirmar = await _confirmar(
      titulo: 'Eliminar cliente',
      mensaje:
          '¿Deseas eliminar a ${cliente.nombre} ${cliente.apellido} '
          '(cédula ${cliente.cedula})?\n\nEsta acción no se puede deshacer.',
      accion: 'Eliminar',
      peligroso: true,
    );
    if (!confirmar || cliente.clienteId == null || !mounted) return;
    try {
      await _api.eliminarCliente(cliente.clienteId!);
      if (!mounted) return;
      _mostrarLocal([
        for (final c in _ultimos)
          if (c.clienteId != cliente.clienteId) c,
      ]);
      _mensaje('Cliente eliminado.');
      await _sincronizar(
        (lista) => !lista.any((c) => c.clienteId == cliente.clienteId),
      );
    } catch (error) {
      if (!mounted) return;
      _mensaje(error.toString());
      await _recargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = _usuario;
    final esquema = Theme.of(context).colorScheme;
    final estrecho = MediaQuery.sizeOf(context).width < 700;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: esquema.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.local_pharmacy,
                color: esquema.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Farmacia',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          if (usuario != null)
            _MenuUsuario(
              usuario: usuario,
              esAdministrador: _esAdministrador,
              compacto: estrecho,
              onCerrarSesion: _cerrarSesion,
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: FutureBuilder<List<Cliente>>(
        future: _clientes,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return _estadoError(snapshot.error);
          final todos = snapshot.data ?? const <Cliente>[];

          return RefreshIndicator(
            onRefresh: _recargar,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1148),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          estrecho ? 16 : 24,
                          20,
                          estrecho ? 16 : 24,
                          8,
                        ),
                        child: _cabecera(estrecho),
                      ),
                    ),
                  ),
                ),
                if (todos.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _estadoVacio(
                      icono: Icons.people_outline,
                      titulo: 'Aún no hay clientes',
                      detalle: _esAdministrador
                          ? 'Crea el primero con el botón "Nuevo cliente".'
                          : 'Cuando se registren clientes aparecerán aquí.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      estrecho ? 16 : 24,
                      8,
                      estrecho ? 16 : 24,
                      96,
                    ),
                    sliver: SliverLayoutBuilder(
                      builder: (context, c) {
                        // Centra y limita el ancho del contenido.
                        const maximo = 1100.0;
                        final lateral = c.crossAxisExtent > maximo + 48
                            ? (c.crossAxisExtent - maximo) / 2 - 24
                            : 0.0;
                        return SliverPadding(
                          padding: EdgeInsets.symmetric(horizontal: lateral),
                          sliver: SliverGrid.builder(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 520,
                                  mainAxisExtent: 168,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                ),
                            itemCount: todos.length,
                            itemBuilder: (context, i) => _TarjetaCliente(
                              cliente: todos[i],
                              esAdministrador: _esAdministrador,
                              onEditar: () =>
                                  _abrirFormulario(cliente: todos[i]),
                              onEliminar: () => _eliminar(todos[i]),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: _esAdministrador && estrecho
          ? FloatingActionButton.extended(
              onPressed: () => _abrirFormulario(),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Nuevo cliente'),
            )
          : null,
    );
  }

  Widget _cabecera(bool estrecho) {
    final tema = Theme.of(context);
    final titulo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Clientes',
          style: tema.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _esAdministrador
              ? 'Administra el registro de clientes de la farmacia.'
              : 'Consulta el registro de clientes (solo lectura).',
          style: tema.textTheme.bodyMedium?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    if (estrecho || !_esAdministrador) return titulo;

    return Row(
      children: [
        Expanded(child: titulo),
        const SizedBox(width: 14),
        FilledButton.icon(
          onPressed: () => _abrirFormulario(),
          style: FilledButton.styleFrom(minimumSize: const Size(180, 52)),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Nuevo cliente'),
        ),
      ],
    );
  }

  Widget _estadoVacio({
    required IconData icono,
    required String titulo,
    required String detalle,
  }) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: tema.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icono, size: 40, color: tema.colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            titulo,
            style: tema.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detalle,
            textAlign: TextAlign.center,
            style: tema.textTheme.bodyMedium?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _estadoError(Object? error) {
    final tema = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: tema.colorScheme.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_off,
                  size: 40,
                  color: tema.colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No se pudo cargar la información',
                style: tema.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(error.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _recargar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
              const SizedBox(height: 10),
              Text(
                'API: ${ApiService.baseUrl}',
                textAlign: TextAlign.center,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuUsuario extends StatelessWidget {
  const _MenuUsuario({
    required this.usuario,
    required this.esAdministrador,
    required this.compacto,
    required this.onCerrarSesion,
  });

  final UsuarioSesion usuario;
  final bool esAdministrador;
  final bool compacto;
  final VoidCallback onCerrarSesion;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final inicial = usuario.nombre.isEmpty
        ? '?'
        : usuario.nombre.characters.first.toUpperCase();
    final rol = esAdministrador ? 'Administrador' : 'Solo lectura';

    return PopupMenuButton<String>(
      tooltip: 'Cuenta',
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (v) {
        if (v == 'salir') onCerrarSesion();
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                usuario.nombre,
                style: tema.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: tema.colorScheme.onSurface,
                ),
              ),
              Text(
                usuario.email,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              _InsigniaRol(texto: rol, admin: esAdministrador),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'salir',
          child: ListTile(
            leading: Icon(Icons.logout),
            title: Text('Cerrar sesión'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: tema.colorScheme.primary,
              foregroundColor: tema.colorScheme.onPrimary,
              child: Text(inicial),
            ),
            if (!compacto) ...[
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      usuario.nombre,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(rol, style: tema.textTheme.labelSmall),
                ],
              ),
              const Icon(Icons.expand_more),
            ],
          ],
        ),
      ),
    );
  }
}

class _InsigniaRol extends StatelessWidget {
  const _InsigniaRol({required this.texto, required this.admin});

  final String texto;
  final bool admin;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final fondo = admin
        ? esquema.primaryContainer
        : esquema.surfaceContainerHigh;
    final color = admin ? esquema.onPrimaryContainer : esquema.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            admin
                ? Icons.admin_panel_settings_outlined
                : Icons.visibility_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            texto,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaCliente extends StatelessWidget {
  const _TarjetaCliente({
    required this.cliente,
    required this.esAdministrador,
    required this.onEditar,
    required this.onEliminar,
  });

  final Cliente cliente;
  final bool esAdministrador;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final inicial = cliente.nombre.isEmpty
        ? '?'
        : cliente.nombre.characters.first.toUpperCase();

    Widget dato(IconData icono, String? texto) {
      if (texto == null || texto.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(icono, size: 15, color: esquema.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tema.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: esquema.primaryContainer,
              foregroundColor: esquema.onPrimaryContainer,
              child: Text(
                inicial,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${cliente.nombre} ${cliente.apellido}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tema.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: esquema.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'C.I. ${cliente.cedula}',
                      style: tema.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  dato(Icons.phone_outlined, cliente.telefono),
                  dato(Icons.email_outlined, cliente.correo),
                  dato(Icons.home_outlined, cliente.direccion),
                ],
              ),
            ),
            if (esAdministrador)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Editar',
                    onPressed: onEditar,
                    icon: const Icon(Icons.edit_outlined),
                    color: esquema.primary,
                  ),
                  IconButton(
                    tooltip: 'Eliminar',
                    onPressed: onEliminar,
                    icon: const Icon(Icons.delete_outline),
                    color: esquema.error,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
