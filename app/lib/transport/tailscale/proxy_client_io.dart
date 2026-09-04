// Native: go out through the userspace tailscaled's own outbound proxy when there is one.
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

http.Client makeTailnetClient(String proxy) {
  if (proxy.isEmpty) return http.Client();
  return IOClient(HttpClient()..findProxy = (_) => 'PROXY $proxy');
}
