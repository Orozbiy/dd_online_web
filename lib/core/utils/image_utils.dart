import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Товар сүрөттөрү үчүн компрессия (мобил + веб)
Future<Uint8List> compressImage(
  Uint8List bytes, {
  int quality   = 60,
  int maxWidth  = 800,
  int maxHeight = 800,
}) async {
  if (kIsWeb) {
    // Веб'де: өлчөмүн кичирейтебиз, JPEG'ке айландыруу Cloudinary тарабынан болот
    return _resizeWeb(bytes, maxWidth: maxWidth, maxHeight: maxHeight);
  }
  final result = await FlutterImageCompress.compressWithList(
    bytes,
    minWidth:  maxWidth,
    minHeight: maxHeight,
    quality:   quality,
    format:    CompressFormat.jpeg,
    keepExif:  false,
  );
  return result.length < bytes.length ? result : bytes;
}

/// Чат сүрөттөрү үчүн
Future<Uint8List> compressChatImage(Uint8List bytes) async {
  if (kIsWeb) return _resizeWeb(bytes, maxWidth: 600, maxHeight: 600);
  final result = await FlutterImageCompress.compressWithList(
    bytes,
    minWidth:  600,
    minHeight: 600,
    quality:   60,
    format:    CompressFormat.jpeg,
    keepExif:  false,
  );
  return result.length < bytes.length ? result : bytes;
}

/// Story сүрөттөрү үчүн
Future<Uint8List> compressStoryImage(Uint8List bytes) async {
  if (kIsWeb) return _resizeWeb(bytes, maxWidth: 1080, maxHeight: 1920);
  final result = await FlutterImageCompress.compressWithList(
    bytes,
    minWidth:  1080,
    minHeight: 1920,
    quality:   60,
    keepExif:  false,
    format:    CompressFormat.jpeg,
  );
  return result.length < bytes.length ? result : bytes;
}

/// Watermark — мобилде гана (веб'де өткөрүп жиберет)
Future<Uint8List> addWatermark(Uint8List bytes) async {
  if (kIsWeb) return bytes; // веб'де watermark жок
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
          textAlign: TextAlign.center, fontSize: fontSize, fontWeight: FontWeight.bold,
        ))
          ..pushStyle(ui.TextStyle(
            color: textColor, fontSize: fontSize,
            fontWeight: FontWeight.bold, letterSpacing: fontSize * 0.1,
          ))
          ..addText('DD Online');
        final para = pb.build()..layout(ui.ParagraphConstraints(width: w * 0.5));
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(-45 * 3.14159265 / 180);
        canvas.drawParagraph(para, Offset(-para.longestLine / 2, -para.height / 2));
        canvas.restore();
      }
      final picture  = recorder.endRecording();
      final finalImg = await picture.toImage(src.width, src.height);
      try {
        final byteData = await finalImg.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) return bytes;
        final recompressed = await FlutterImageCompress.compressWithList(
          byteData.buffer.asUint8List(),
          minWidth: src.width, minHeight: src.height,
          quality: 60, format: CompressFormat.jpeg, keepExif: false,
        );
        return recompressed.length < bytes.length ? recompressed : bytes;
      } finally {
        finalImg.dispose();
      }
    } finally {
      src.dispose();
    }
  } catch (e) {
    debugPrint('⚠️ Watermark ката: $e');
    return bytes;
  }
}

/// Веб'де сүрөт өлчөмүн кичирейтүү (PNG форматта)
Future<Uint8List> _resizeWeb(
  Uint8List bytes, {
  int maxWidth  = 800,
  int maxHeight = 800,
}) async {
  try {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth:  maxWidth,
      targetHeight: maxHeight,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return bytes;
      final result = data.buffer.asUint8List();
      debugPrint('🗜 Web resize: ${bytes.length ~/ 1024}KB → ${result.length ~/ 1024}KB');
      return result;
    } finally {
      image.dispose();
    }
  } catch (e) {
    debugPrint('⚠️ Web resize ката: $e');
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