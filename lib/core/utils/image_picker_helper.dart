// lib/core/utils/image_picker_helper.dart
import 'dart:typed_data';

import 'web_image_picker_stub.dart'
    if (dart.library.html) 'web_image_picker.dart';

Future<Uint8List?> pickWebImage() => pickImageFromWeb();