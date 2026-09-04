// The browser cannot be told to use a proxy, and does not need to be: on iOS the Tailscale app
// owns the tunnel, so a request to a tailnet address goes there by itself.
import 'package:http/http.dart' as http;

http.Client makeTailnetClient(String proxy) => http.Client();
