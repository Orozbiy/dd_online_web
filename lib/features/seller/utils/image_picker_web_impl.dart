// lib/features/seller/utils/image_picker_web_impl.dart
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:typed_data';

Future<Uint8List?> pickImageWeb() async {
  final completer = Completer<Uint8List?>();

  final input = html.FileUploadInputElement()..accept = 'image/*';
  input.click();

  input.onChange.listen((event) {
    final file = input.files?.first;
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

  return completer.future;
}
