import 'dart:js_interop';
import 'dart:async';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Сүрөттү тандап, браузердин Canvas аркылуу:
///  - aspect ratio сактап масштабтайт (maxDimension боюнча)
///  - JPEG quality=0.85 менен сыгат
///  - натыйжада ~80–180 KB болот (оригинал форматына жараша)
Future<Uint8List?> pickImageFromWeb({int maxDimension = 1200}) async {
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
      final dataUrl = reader.result;
      if (dataUrl == null) {
        completer.complete(null);
        return;
      }

      final img = web.HTMLImageElement();

      img.addEventListener('load', (web.Event _) {
        final origW = img.naturalWidth;
        final origH = img.naturalHeight;

        // Aspect ratio сактап, максималдуу өлчөмдү эсептейбиз
        double scale = 1.0;
        if (origW > origH) {
          if (origW > maxDimension) scale = maxDimension / origW;
        } else {
          if (origH > maxDimension) scale = maxDimension / origH;
        }

        final targetW = (origW * scale).round();
        final targetH = (origH * scale).round();

        // Canvas'ка тартабыз
        final canvas = web.HTMLCanvasElement()
          ..width  = targetW
          ..height = targetH;

        final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
        // drawImageScaled: source img, dest x, dest y, dest width, dest height
        ctx.drawImageScaled(img, 0, 0, targetW.toDouble(), targetH.toDouble());

        // JPEG катары алабыз (quality=0.85)
        canvas.toBlob(
          (web.Blob? blob) {
            if (blob == null) {
              completer.complete(null);
              return;
            }
            final blobReader = web.FileReader();
            blobReader.addEventListener('loadend', (web.Event _) {
              final blobResult = blobReader.result;
              if (blobResult != null) {
                final buffer = (blobResult as JSArrayBuffer).toDart;
                completer.complete(Uint8List.view(buffer));
              } else {
                completer.complete(null);
              }
            }.toJS);
            blobReader.readAsArrayBuffer(blob);
          }.toJS,
          'image/jpeg',
          0.85.toJS,
        );
      }.toJS);

      img.src = dataUrl as String;
    }.toJS);

    reader.readAsDataURL(file);
  }.toJS);

  web.document.body!.append(input);
  input.click();

  return completer.future;
}