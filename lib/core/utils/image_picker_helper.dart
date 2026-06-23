// lib/core/utils/image_picker_helper.dart
import 'dart:typed_data';

// Conditional import — веб үчүн dart:html версия, башкалар үчүн stub
import 'web_image_picker.dart'
    if (dart.library.io) 'web_image_picker_stub.dart';

Future<Uint8List?> pickWebImage() => pickImageFromWeb();