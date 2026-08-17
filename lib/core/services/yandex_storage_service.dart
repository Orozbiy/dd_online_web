import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class YandexStorageService {
  YandexStorageService._();
  static final YandexStorageService instance = YandexStorageService._();

  // ── Supabase (веб үчүн) ──
  static final _supabase = Supabase.instance.client;
  static const _supaBucket = 'product-images';

  // ── Backblaze (мобил үчүн) ──
  static const _accessKeyId = '00372b9ef8f7c080000000001';
  static const _secretKey   = 'K003kbcRF9atVj3Si0xJG9dfLe7BiS8';
  static const _bucket      = 'dd-online-media';
  static const _region      = 'eu-central-003';
  static const _host        = 's3.eu-central-003.backblazeb2.com';
  static const _endpoint    = 'https://$_host';

  static String _bbPublicUrl(String objectKey) =>
      'https://$_bucket.$_host/$objectKey';

  // ═══════════════════════════════════════
  // НЕГИЗГИ: Сүрөт жүктөө
  // ═══════════════════════════════════════
  Future<String?> uploadImage(
    Uint8List bytes, {
    required String folder,
    String? filename,
    String contentType = 'image/jpeg',
  }) async {
    final name = filename ?? '${folder}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    if (kIsWeb) {
      // ВЕБ → Supabase (CORS маселеси жок)
      return _supabaseUpload(bytes, path: '$folder/$name', contentType: contentType);
    } else {
      // МОБИЛ → Backblaze
      return _put(bytes, '$folder/$name', contentType);
    }
  }

  // ═══════════════════════════════════════
  // НЕГИЗГИ: Аудио жүктөө
  // ═══════════════════════════════════════
  Future<String?> uploadAudio(
    Uint8List bytes, {
    required String folder,
    String? filename,
  }) async {
    final name = filename ?? 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

    if (kIsWeb) {
      return _supabaseUpload(bytes, path: '$folder/$name', contentType: 'audio/m4a');
    } else {
      return _put(bytes, '$folder/$name', 'audio/m4a');
    }
  }

  // ═══════════════════════════════════════
  // Supabase жүктөө (веб)
  // ═══════════════════════════════════════
  Future<String?> _supabaseUpload(
    Uint8List bytes, {
    required String path,
    required String contentType,
  }) async {
    try {
      await _supabase.storage.from(_supaBucket).uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: contentType, upsert: true),
      );
      final url = _supabase.storage.from(_supaBucket).getPublicUrl(path);
      print('✅ Supabase жүктөлдү: $url');
      return url;
    } catch (e) {
      print('❌ Supabase ката: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════
  // Backblaze PUT (мобил)
  // ═══════════════════════════════════════
  Future<String?> _put(Uint8List body, String objectKey, String contentType) async {
    try {
      final now      = DateTime.now().toUtc();
      final dateStr  = _dateStr(now);
      final timeStr  = _timeStr(now);
      final bodyHash = sha256.convert(body).toString();

      final canonicalUri = '/$_bucket/$objectKey';
      final canonicalHeaders =
          'content-type:$contentType\n'
          'host:$_host\n'
          'x-amz-acl:public-read\n'
          'x-amz-content-sha256:$bodyHash\n'
          'x-amz-date:$timeStr\n';
      const signedHeaders =
          'content-type;host;x-amz-acl;x-amz-content-sha256;x-amz-date';

      final canonicalRequest = [
        'PUT', canonicalUri, '',
        canonicalHeaders, signedHeaders, bodyHash,
      ].join('\n');

      final credentialScope = '$dateStr/$_region/s3/aws4_request';
      final stringToSign = [
        'AWS4-HMAC-SHA256', timeStr, credentialScope,
        sha256.convert(utf8.encode(canonicalRequest)).toString(),
      ].join('\n');

      final signingKey    = _signingKey(dateStr);
      final signature     = Hmac(sha256, signingKey).convert(utf8.encode(stringToSign)).toString();
      final authorization =
          'AWS4-HMAC-SHA256 '
          'Credential=$_accessKeyId/$credentialScope, '
          'SignedHeaders=$signedHeaders, '
          'Signature=$signature';

      final uri = Uri.parse('$_endpoint/$_bucket/$objectKey');
      final response = await http.put(
        uri,
        headers: {
          'Content-Type':          contentType,
          'Host':                  _host,
          'x-amz-acl':            'public-read',
          'x-amz-content-sha256':  bodyHash,
          'x-amz-date':            timeStr,
          'Authorization':         authorization,
        },
        body: body,
      ).timeout(const Duration(seconds: 90));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final url = _bbPublicUrl(objectKey);
        print('✅ Backblaze жүктөлдү: $url');
        return url;
      }
      print('❌ Backblaze ката: ${response.statusCode}\n${response.body}');
      return null;
    } catch (e) {
      print('❌ Backblaze exception: $e');
      return null;
    }
  }

  List<int> _signingKey(String dateStr) {
    final kDate    = _hmac(utf8.encode('AWS4$_secretKey'), dateStr);
    final kRegion  = _hmac(kDate, _region);
    final kService = _hmac(kRegion, 's3');
    return _hmac(kService, 'aws4_request');
  }

  List<int> _hmac(List<int> key, String data) =>
      Hmac(sha256, key).convert(utf8.encode(data)).bytes;

  String _dateStr(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}'
      '${dt.month.toString().padLeft(2, '0')}'
      '${dt.day.toString().padLeft(2, '0')}';

  String _timeStr(DateTime dt) =>
      '${_dateStr(dt)}T'
      '${dt.hour.toString().padLeft(2, '0')}'
      '${dt.minute.toString().padLeft(2, '0')}'
      '${dt.second.toString().padLeft(2, '0')}Z';
}