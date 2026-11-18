# Farmacia

Aplicacion Flutter para el CRUD de clientes de la API Flask `Leccion`, el inicio de sesion con correo y contrasena, y los proveedores sociales.

## Estructura

- `lib/models/`: modelos de clientes y sesion.
- `lib/pages/`: acceso, registro, listado y formulario de clientes.
- `lib/services/`: API HTTP, autenticacion y cliente HTTP.

## Ejecutar en Flutter Web

El callback OAuth de Flask redirige a `http://localhost:4200`. Inicia Flutter Web en ese puerto y apunta la API al mismo host HTTPS usado para OAuth, para que el navegador envie la cookie de sesion:

```bash
flutter pub get
flutter run -d chrome --web-port 4200 \
  --dart-define=API_BASE_URL=https://float-egotism-dispersed.ngrok-free.dev \
  --dart-define=OAUTH_BASE_URL=https://float-egotism-dispersed.ngrok-free.dev
```

Si cambia el dominio ngrok, actualiza ambos valores. Flask permite el origen `http://localhost:4200` en CORS y configura la cookie como `SameSite=None; Secure` para el flujo web.

## Autenticacion y roles

La pantalla inicial permite iniciar sesion con correo y contrasena o registrar una cuenta con nombre, correo y contrasena. El registro exige al menos ocho caracteres. Flutter consume `POST /api/auth/register` y `POST /api/auth/login`; el rol devuelto controla la interfaz:

- `Administrador`: puede crear, editar y eliminar clientes.
- `Usuario`: puede consultar la lista y actualizarla.

La API valida tambien los permisos en el servidor. Un rol ausente o desconocido se trata como usuario en modo de solo lectura.

Los botones sociales existentes siguen disponibles. La autenticacion web conserva la cookie del navegador; para Android/iOS, Flutter guarda la cookie de sesion recibida por HTTP y la reenvia a la API mientras la app esta abierta.
