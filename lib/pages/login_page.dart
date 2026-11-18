import 'package:flutter/material.dart';

import '../models/usuario_sesion.dart';
import '../services/auth_service.dart';
import '../services/sesion_store.dart';
import '../utils/validadores.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nombre = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _abriendo = false;
  bool _registrando = false;
  bool _mostrarPassword = false;

  @override
  void initState() {
    super.initState();
    // Flask devuelve estos datos en la URL después de OAuth.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final sesion = _authService.leerSesionDesdeUrl();
        if (sesion != null) {
          _irAClientes(sesion);
        } else if (SesionStore.actual != null) {
          // Sesión recordada: evita volver a pedir login al recargar.
          _irAClientes(SesionStore.actual!);
        }
      } catch (error) {
        _mensaje(error.toString());
      }
    });
  }

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _irAClientes(UsuarioSesion sesion) {
    SesionStore.guardar(sesion);
    Navigator.pushReplacementNamed(context, '/clientes', arguments: sesion);
  }

  Future<void> _iniciar(Future<void> Function() accion) async {
    setState(() => _abriendo = true);
    try {
      await accion();
    } catch (error) {
      if (mounted) _mensaje(error.toString());
    } finally {
      if (mounted) setState(() => _abriendo = false);
    }
  }

  Future<void> _enviarFormulario() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _abriendo = true);
    try {
      final UsuarioSesion sesion;
      if (_registrando) {
        sesion = await _authService.registrarUsuario(
          nombre: Validadores.normalizar(_nombre.text),
          email: _email.text.trim().toLowerCase(),
          password: _password.text,
        );
      } else {
        sesion = await _authService.iniciarSesion(
          email: _email.text.trim().toLowerCase(),
          password: _password.text,
        );
      }
      if (mounted) _irAClientes(sesion);
    } catch (error) {
      if (mounted) _mensaje(error.toString());
    } finally {
      if (mounted) setState(() => _abriendo = false);
    }
  }

  String? _validarNombre(String? valor) =>
      _registrando ? Validadores.nombre(valor, campo: 'El nombre') : null;

  String? _validarEmail(String? valor) => Validadores.correoElectronico(valor);

  String? _validarPassword(String? valor) =>
      Validadores.contrasena(valor, registro: _registrando);

  void _mensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  void _cambiarModo() {
    setState(() {
      _registrando = !_registrando;
      _formKey.currentState?.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _tarjetaFormulario(context, mostrarMarca: true),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tarjetaFormulario(
    BuildContext context, {
    required bool mostrarMarca,
  }) {
    final tema = Theme.of(context);
    final titulo = _registrando ? 'Crear cuenta' : 'Iniciar sesión';
    final subtitulo = _registrando
        ? 'Completa tus datos para registrarte'
        : 'Ingresa tus credenciales para continuar';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (mostrarMarca) ...[
                Center(child: _LogoMarca(tamano: 56)),
                const SizedBox(height: 16),
              ],
              Text(
                titulo,
                textAlign: mostrarMarca ? TextAlign.center : TextAlign.start,
                style: tema.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitulo,
                textAlign: mostrarMarca ? TextAlign.center : TextAlign.start,
                style: tema.textTheme.bodyMedium?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.topCenter,
                child: _registrando
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: TextFormField(
                          controller: _nombre,
                          enabled: !_abriendo,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          inputFormatters: Validadores.conLimite(
                            Validadores.soloLetras,
                            50,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Nombre',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: _validarNombre,
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              TextFormField(
                controller: _email,
                enabled: !_abriendo,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                inputFormatters: Validadores.conLimite(Validadores.correo, 100),
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: _validarEmail,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                enabled: !_abriendo,
                obscureText: !_mostrarPassword,
                inputFormatters: Validadores.conLimite(
                  Validadores.password,
                  64,
                ),
                autofillHints: [
                  _registrando
                      ? AutofillHints.newPassword
                      : AutofillHints.password,
                ],
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  helperText: _registrando
                      ? 'Mínimo 8 caracteres, con letras y números'
                      : null,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _mostrarPassword
                        ? 'Ocultar contraseña'
                        : 'Mostrar contraseña',
                    onPressed: () =>
                        setState(() => _mostrarPassword = !_mostrarPassword),
                    icon: Icon(
                      _mostrarPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                validator: _validarPassword,
                onFieldSubmitted: (_) => _enviarFormulario(),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _abriendo ? null : _enviarFormulario,
                child: _abriendo
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(titulo),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'o continúa con',
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _BotonSocial(
                      tooltip: 'Continuar con Google',
                      icono: Icons.g_mobiledata,
                      etiqueta: 'Google',
                      onPressed: _abriendo
                          ? null
                          : () => _iniciar(_authService.iniciarConGoogle),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _BotonSocial(
                      tooltip: 'Continuar con Facebook',
                      icono: Icons.facebook,
                      etiqueta: 'Facebook',
                      onPressed: _abriendo
                          ? null
                          : () => _iniciar(_authService.iniciarConFacebook),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _BotonSocial(
                      tooltip: 'Continuar con Instagram',
                      icono: Icons.camera_alt_outlined,
                      etiqueta: 'Instagram',
                      onPressed: _abriendo
                          ? null
                          : () => _iniciar(_authService.iniciarConInstagram),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _registrando ? '¿Ya tienes cuenta?' : '¿No tienes cuenta?',
                    style: tema.textTheme.bodyMedium,
                  ),
                  TextButton(
                    onPressed: _abriendo ? null : _cambiarModo,
                    child: Text(_registrando ? 'Inicia sesión' : 'Regístrate'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoMarca extends StatelessWidget {
  const _LogoMarca({required this.tamano});

  final double tamano;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Container(
      width: tamano * 1.5,
      height: tamano * 1.5,
      decoration: BoxDecoration(
        color: esquema.primaryContainer,
        borderRadius: BorderRadius.circular(tamano * 0.45),
      ),
      child: Icon(Icons.local_pharmacy, size: tamano, color: esquema.primary),
    );
  }
}

class _BotonSocial extends StatelessWidget {
  const _BotonSocial({
    required this.tooltip,
    required this.icono,
    required this.etiqueta,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icono;
  final String etiqueta;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 24),
            const SizedBox(height: 2),
            Text(
              etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
