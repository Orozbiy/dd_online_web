import 'dart:js_interop';
import 'dart:async';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<Uint8List?> pickImageFromWeb() async {
  final completer = Completer<Uint8List?>();

  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/*';

  input.addEventListener('change', (web.Event _) {
    final files = input.files;
    if (files == null || files.length == 0) {
      completer.complete(null);
      return;
    }
    final file = files.item(0)!;
    final reader = web.FileReader();
    reader.addEventListener('loadend', (web.Event _) {
      final result = reader.result;
      if (result != null) {
        final buffer = (result as JSArrayBuffer).toDart;
        completer.complete(Uint8List.view(buffer));
      } else {
        completer.complete(null);
      }
    }.toJS);
    reader.readAsArrayBuffer(file);
  }.toJS);

  web.document.body!.append(input);
  input.click();
  // ❌ input.remove() — АЛЫНДЫ

  return completer.future;
}