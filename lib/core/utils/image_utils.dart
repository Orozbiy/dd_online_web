import 'dart:typed_data';

/// Веб үчүн: сыгуу жок, түздөн-түз кайтарабыз
Future<Uint8List> compressImage(
  Uint8List bytes, {
  int quality = 80,
  int maxWidth = 1024,
  int maxHeight = 1024,
}) async {
  return bytes;
}

/// Cloudinary URL'ин thumbnail'га айлантуу
String toCloudinaryThumb(String url, {int width = 400}) {
  if (url.contains('res.cloudinary.com') && url.contains('/upload/')) {
    return url.replaceFirst(
      '/upload/',
      '/upload/w_$width,q_auto,f_auto/',
    );
  }
  return url;
}