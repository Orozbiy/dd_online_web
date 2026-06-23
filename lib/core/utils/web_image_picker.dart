// lib/core/utils/web_image_picker.dart
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:typed_data';

Future<Uint8List?> pickImageFromWeb() async {
  final completer = Completer<Uint8List?>();

  final uploadInput = html.FileUploadInputElement()
    ..accept = 'image/*';

  uploadInput.onChange.listen((event) {
    final file = uploadInput.files?.first;
    if (file == null) {
      completer.complete(null);
      return;
    }
    final reader = html.FileReader();
    reader.onLoadEnd.listen((e) {
      final result = reader.result;
      if (result is ByteBuffer) {
        completer.complete(Uint8List.view(result));
      } else {
        completer.complete(null);
      }
    });
    reader.readAsArrayBuffer(file);
  });

  uploadInput.click();

  return completer.future;
}