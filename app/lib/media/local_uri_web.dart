import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

final Map<String, Uri> _cache = {};
const bool isWeb = true;

Future<Uri> localUriFor(String hash, Uint8List bytes, String mime) async {
  final cached = _cache[hash];
  if (cached != null) return cached;
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  return _cache[hash] = Uri.parse(url);
}
