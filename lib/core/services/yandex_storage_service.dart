import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class YandexStorageService {
  YandexStorageService._();
  static final YandexStorageService instance = YandexStorageService._();

  // ── ВЕБ: Supabase Storage (Backblaze'ге браузерден түз жүктөө CORS'ко такалат) ──
  static const _supaBucket = 'product-images';

  static const _accessKeyId = '00372b9ef8f7c080000000001';
  static const _secretKey   = 'K003kbcRF9atVj3Si0xJG9dfLe7BiS8';
  static const _bucket      = 'dd-online-media';
  static const _region      = 'eu-central-003';
  static const _host        = 's3.eu-central-003.backblazeb2.com';
  static const _endpoint    = 'https://$_host';

  // Backblaze B2 S3-compatible URL форматы:
  // PUT: https://s3.{region}.backblazeb2.com/{bucket}/{key}
  // GET: https://{bucket}.s3.{region}.backblazeb2.com/{key}
  //   же: https://s3.{region}.backblazeb2.com/{bucket}/{key}  (экөө тең иштейт)
  // Биз PUT менен бирдей форматты колдонобуз — ишенимдүүрөөк
  static String publicUrl(String objectKey) =>
      '$_endpoint/$_bucket/$objectKey';

  /// Объект key'ин URL'ден чыгарат (эски/жаңы форматтардын экөөнү тең колдойт)
  /// https://s3.eu-central-003.backblazeb2.com/dd-online-media/chat/audio.m4a
  ///   → chat/audio.m4a
  /// https://dd-online-media.s3.eu-central-003.backblazeb2.com/chat/audio.m4a
  ///   → chat/audio.m4a
  static String? extractObjectKey(String url) {
    // Жаңы формат: /dd-online-media/KEY
    final newPattern = RegExp(
      r'^https://s3\.eu-central-003\.backblazeb2\.com/dd-online-media/(.+)$',
    );
    final newMatch = newPattern.firstMatch(url);
    if (newMatch != null) return newMatch.group(1);

    // Эски формат: bucket subdomain
    final oldPattern = RegExp(
      r'^https://dd-online-media\.s3\.eu-central-003\.backblazeb2\.com/(.+)$',
    );
    final oldMatch = oldPattern.firstMatch(url);
    if (oldMatch != null) return oldMatch.group(1);

    return null;
  }

  /// Presigned GET URL — убактылуу signed URL (жеке bucket'тен ойнотуу/жүктөп алуу үчүн)
  /// [url] — Supabase'де сакталган толук URL же objectKey
  /// [expiresSeconds] — канча секунд жарактуу (default: 3600 = 1 саат)
  String presignedUrl(String url, {int expiresSeconds = 3600}) {
    // URL'ден objectKey чыгар (же болбосо, URL'дин өзү objectKey катары эсептелет)
    final objectKey = extractObjectKey(url) ?? url;

    final now          = DateTime.now().toUtc();
    final dateStr      = _dateStr(now);
    final timeStr      = _timeStr(now);
    final canonicalUri = '/$_bucket/${_uriEncode(objectKey)}';
    final credential   = '$_accessKeyId/$dateStr/$_region/s3/aws4_request';

    // Query параметрлер (алфавит боюнча сорттолгон болушу керек!)
    final queryParams = {
      'X-Amz-Algorithm':     'AWS4-HMAC-SHA256',
      'X-Amz-Credential':    credential,
      'X-Amz-Date':          timeStr,
      'X-Amz-Expires':       expiresSeconds.toString(),
      'X-Amz-SignedHeaders': 'host',
    };

    final sortedKeys = queryParams.keys.toList()..sort();
    final canonicalQueryString = sortedKeys
        .map((k) => '${_uriEncodeParam(k)}=${_uriEncodeParam(queryParams[k]!)}')
        .join('&');

    final canonicalHeaders = 'host:$_host\n';
    const signedHeaders    = 'host';

    final canonicalRequest = [
      'GET',
      canonicalUri,
      canonicalQueryString,
      canonicalHeaders,
      signedHeaders,
      'UNSIGNED-PAYLOAD',
    ].join('\n');

    final credentialScope = '$dateStr/$_region/s3/aws4_request';
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      timeStr,
      credentialScope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');

    final signingKey = _signingKey(dateStr);
    final signature  = Hmac(sha256, signingKey)
        .convert(utf8.encode(stringToSign))
        .toString();

    final encodedKey = _uriEncode(objectKey);
    return '$_endpoint/$_bucket/$encodedKey'
        '?$canonicalQueryString'
        '&X-Amz-Signature=$signature';
  }

  Future<String?> uploadImage(
    Uint8List bytes, {
    required String folder,
    String? filename,
    String contentType = 'image/jpeg',
  }) async {
    final name = filename ?? '${folder}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final objectKey = '$folder/$name';
    // ВЕБ → Supabase, МОБИЛ → Backblaze
    if (kIsWeb) {
      return _supabaseUpload(bytes, path: objectKey, contentType: contentType);
    }
    return _put(bytes, objectKey, contentType);
  }

  Future<String?> uploadAudio(
    Uint8List bytes, {
    required String folder,
    String? filename,
    String contentType = 'audio/m4a',
  }) async {
    final name = filename ?? 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final objectKey = '$folder/$name';
    if (kIsWeb) {
      return _supabaseUpload(bytes, path: objectKey, contentType: contentType);
    }
    return _put(bytes, objectKey, contentType);
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
      final storage = Supabase.instance.client.storage.from(_supaBucket);
      await storage.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: contentType, upsert: true),
      );
      final url = storage.getPublicUrl(path);
      debugPrint('✅ Supabase жүктөлдү: $url');
      return url;
    } catch (e) {
      debugPrint('❌ Supabase ката: $e');
      return null;
    }
  }

  Future<String?> _put(Uint8List body, String objectKey, String contentType) async {
    try {
      final now      = DateTime.now().toUtc();
      final dateStr  = _dateStr(now);
      final timeStr  = _timeStr(now);
      final bodyHash = sha256.convert(body).toString();

      final canonicalUri     = '/$_bucket/$objectKey';
      final canonicalHeaders =
          'content-type:$contentType\n'
          'host:$_host\n'
          'x-amz-content-sha256:$bodyHash\n'
          'x-amz-date:$timeStr\n';
      const signedHeaders = 'content-type;host;x-amz-content-sha256;x-amz-date';

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
      final response = await http.put(uri, headers: {
        'Content-Type':         contentType,
        'Host':                 _host,
        'x-amz-content-sha256': bodyHash,
        'x-amz-date':          timeStr,
        'Authorization':        authorization,
      }, body: body).timeout(const Duration(seconds: 90));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return publicUrl(objectKey);
      }
      print('❌ Backblaze ката: ${response.statusCode}\n${response.body}');
      return null;
    } catch (e) {
      print('❌ Backblaze exception: $e');
      rethrow; // Жогорку деңгээлге катаны жибер
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

  /// URI encoding (path segments үчүн — / сакталат)
  static String _uriEncode(String input) {
    return input.split('/').map(_uriEncodeParam).join('/');
  }

  /// URI encoding (query param үчүн — баары encode болот)
  static String _uriEncodeParam(String input) {
    return Uri.encodeQueryComponent(input).replaceAll('+', '%20');
  }
}