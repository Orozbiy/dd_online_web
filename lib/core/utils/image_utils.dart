import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Товар сүрөттөрү үчүн компрессия
/// maxWidth/maxHeight — сүрөт ушул өлчөмдөн ЧОҢ болсо КИЧИРЕЙТЕТ
Future<Uint8List> compressImage(
  Uint8List bytes, {
  int quality = 75,
  int maxWidth = 800,
  int maxHeight = 800,
}) async {
  if (kIsWeb) return bytes;
  final result = await FlutterImageCompress.compressWithList(
    bytes,
    minWidth:  maxWidth,   // flutter_image_compress-та бул чынында MAX катары иштейт
    minHeight: maxHeight,  // сүрөт кичине болсо чоңоюп кетпейт
    quality:   quality,
    format:    CompressFormat.jpeg,
    keepExif:  false,
  );
  // ✅ Эгер compress оригиналдан чоң болсо — оригиналды кайтар
  return result.length < bytes.length ? result : bytes;
}

/// Чат сүрөттөрү үчүн — кичирек өлчөм
Future<Uint8List> compressChatImage(Uint8List bytes) async {
  if (kIsWeb) return bytes;
  final result = await FlutterImageCompress.compressWithList(
    bytes,
    minWidth:  600,
    minHeight: 600,
    quality:   65,
    format:    CompressFormat.jpeg,
    keepExif:  false,
  );
  return result.length < bytes.length ? result : bytes;
}

/// Story сүрөттөрү үчүн
Future<Uint8List> compressStoryImage(Uint8List bytes) async {
  if (kIsWeb) return bytes;
  final result = await FlutterImageCompress.compressWithList(
    bytes,
    minWidth:  1080,
    minHeight: 1920,
    quality:   80,   // 85 → 80, Cloudinary'ды аябай толтурбайт
    keepExif:  false,
    format:    CompressFormat.jpeg,
  );
  return result.length < bytes.length ? result : bytes;
}

/// Товар сүрөтүнө "DD Online" watermark кош
/// ✅ Watermark'тан кийин JPEG'ке re-compress — PNG чоңойуп кетпейт
Future<Uint8List> addWatermark(Uint8List bytes) async {
  if (kIsWeb) return bytes;

  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final src   = frame.image;

    try {
      final w = src.width.toDouble();
      final h = src.height.toDouble();

      final recorder = ui.PictureRecorder();
      final canvas   = Canvas(recorder);
      canvas.drawImage(src, Offset.zero, Paint());

      final fontSize  = w * 0.042;
      final textColor = const Color(0x26FFFFFF);

      final positions = [
        Offset(w * 0.18, h * 0.50),
        Offset(w * 0.82, h * 0.50),
        Offset(w * 0.50, h * 0.18),
        Offset(w * 0.50, h * 0.82),
        Offset(w * 0.50, h * 0.50),
      ];

      for (final pos in positions) {
        final pb = ui.ParagraphBuilder(ui.ParagraphStyle(
          textAlign:  TextAlign.center,
          fontSize:   fontSize,
          fontWeight: FontWeight.bold,
        ))
          ..pushStyle(ui.TextStyle(
            color:         textColor,
            fontSize:      fontSize,
            fontWeight:    FontWeight.bold,
            letterSpacing: fontSize * 0.1,
          ))
          ..addText('DD Online');

        final para = pb.build()
          ..layout(ui.ParagraphConstraints(width: w * 0.5));

        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(-45 * 3.14159265 / 180);
        canvas.drawParagraph(
          para,
          Offset(-para.longestLine / 2, -para.height / 2),
        );
        canvas.restore();
      }

      final picture  = recorder.endRecording();
      final finalImg = await picture.toImage(src.width, src.height);

      try {
        final byteData = await finalImg.toByteData(
          format: ui.ImageByteFormat.png, // watermark PNG'де чыгат
        );
        if (byteData == null) return bytes;

        // ✅ НЕГИЗГИ ОҢДОО: PNG → JPEG re-compress, өлчөмдү да кичирейт
        final recompressed = await FlutterImageCompress.compressWithList(
          byteData.buffer.asUint8List(),
          minWidth:  src.width,   // оригинал өлчөмдү сакта (чоңоюп кетпесин)
          minHeight: src.height,
          quality:   82,          // 88 → 82, Cloudinary памятын аябайт
          format:    CompressFormat.jpeg,
          keepExif:  false,
        );

        // ✅ Эгер watermark+compress оригиналдан чоң болсо — bytes кайтар
        return recompressed.length < bytes.length ? recompressed : bytes;
      } finally {
        finalImg.dispose();
      }
    } finally {
      src.dispose();
    }
  } catch (e) {
    debugPrint('⚠️ Watermark ката (оригинал колдонулат): $e');
    return bytes;
  }
}

/// Cloudinary URL'ду thumbnail версиясына айлантуу
String toCloudinaryThumb(String url, {int width = 400}) {
  if (url.contains('res.cloudinary.com') && url.contains('/upload/')) {
    return url.replaceFirst('/upload/', '/upload/w_$width,q_auto,f_auto/');
  }
  return url;
}