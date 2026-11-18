import 'package:http/http.dart' as http;

import 'api_http_client_factory_stub.dart'
    if (dart.library.js_interop) 'api_http_client_factory_web.dart'
    as platform;

http.Client createApiHttpClient() => platform.createApiHttpClient();
