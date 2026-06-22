import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Товар сүрөттөрү үчүн компрессия
Future<Uint8List> compressImage(
  Uint8List bytes, {
  int quality = 75,
  int maxWidth = 800,
  int maxHeight = 800,
}) async {
  final result = await FlutterImageCompress.compressWithList(
    bytes,
    minWidth: maxWidth,
    minHeight: maxHeight,
    quality: quality,
    format: CompressFormat.jpeg,
    keepExif: false,
  );
  return result;
}

/// Чат сүрөттөрү үчүн
Future<Uint8List> compressChatImage(Uint8List bytes) async {
  return FlutterImageCompress.compressWithList(
    bytes,
    minWidth: 800,
    minHeight: 800,
    quality: 70,
    format: CompressFormat.jpeg,
  );
}

/// Story сүрөттөрү үчүн
Future<Uint8List> compressStoryImage(Uint8List bytes) async {
  return FlutterImageCompress.compressWithList(
    bytes,
    minWidth: 1080,
    minHeight: 1920,
    quality: 85,
    keepExif: false,
    format: CompressFormat.jpeg,
  );
}

// ─────────────────────────────────────────────────────────────
// WATERMARK — dart:ui, сервер жок
// ─────────────────────────────────────────────────────────────

/// Товар сүрөтүнө "DD Online" watermark кош (ылдый ортосунда)
Future<Uint8List> addWatermark(Uint8List bytes) async {
  final codec  = await ui.instantiateImageCodec(bytes);
  final frame  = await codec.getNextFrame();
  final src    = frame.image;

  try {
    final w = src.width.toDouble();
    final h = src.height.toDouble();

    final recorder = ui.PictureRecorder();
    final canvas   = Canvas(recorder);
    canvas.drawImage(src, Offset.zero, Paint());

    final fontSize = w * 0.042;
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
        format: ui.ImageByteFormat.png,
      );

      return FlutterImageCompress.compressWithList(
        byteData!.buffer.asUint8List(),
        minWidth:  src.width,
        minHeight: src.height,
        quality:   88,
        format:    CompressFormat.jpeg,
      );
    } finally {
      finalImg.dispose();
    }
  } finally {
    src.dispose(); // ← src колдонулуп бүткөндөн КИЙИН dispose
  }
}

// Cloudinary URL thumbnail
String toCloudinaryThumb(String url, {int width = 400}) {
  if (url.contains('res.cloudinary.com') && url.contains('/upload/')) {
    return url.replaceFirst('/upload/', '/upload/w_$width,q_auto,f_auto/');
  }
  return url;
}