import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class RoboflowService {
  final String apiKey;
  final String modelId; // e.g. "medicine-box/1"
  // Endpoint task: "detect" for object detection, "segment" for instance/semantic segmentation
  final String taskEndpoint;
  // Optional explicit API host. If provided (non-empty), takes precedence over taskEndpoint.
  // Example: "serverless.roboflow.com" to mirror Python InferenceHTTPClient usage.
  final String apiHost;

  RoboflowService({
    required this.apiKey,
    required this.modelId,
    String? apiHost,
    this.taskEndpoint = 'detect',
  }) : apiHost = (apiHost ?? 'serverless.roboflow.com');

  String get _resolvedHost {
    // If apiHost is explicitly set (defaulting to serverless), use it; otherwise fall back to task-based host
    return apiHost.isNotEmpty ? apiHost : '$taskEndpoint.roboflow.com';
  }

  Uri _buildUri({Map<String, String>? extraParams}) {
    final params = {
      'api_key': apiKey,
      'format': 'json',
      ...?extraParams,
    };
    final query = params.entries
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return Uri.parse('https://$_resolvedHost/$modelId?$query');
  }

  Future<Map<String, dynamic>> inferImageFile(
      File imageFile, {
        Map<String, String>? params,
        Duration timeout = const Duration(seconds: 30),
      }) async {
    final uri = _buildUri(extraParams: params);
    // Read and compress image to avoid "entity too large" errors
    final originalBytes = await imageFile.readAsBytes();
    final compressedBytes = await FlutterImageCompress.compressWithList(
      originalBytes,
      minWidth: 1024,
      minHeight: 1024,
      quality: 75,
      format: _inferImageSubtype(imageFile.path) == 'png'
          ? CompressFormat.png
          : CompressFormat.jpeg,
    );
    final bytes = compressedBytes.isNotEmpty ? compressedBytes : originalBytes;

    // First attempt: raw bytes (application/octet-stream)
    try {
      final resp = await http
          .post(
        uri,
        headers: {
          'Content-Type': 'application/octet-stream',
          'Accept': 'application/json',
        },
        body: bytes,
      )
          .timeout(timeout);

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }

      // If server complains about multipart or parsing, fall back
      final lower = resp.body.toLowerCase();
      final looksLikeMultipartNeeded =
          resp.statusCode >= 400 && (lower.contains('multipart') || lower.contains('parse'));
      if (!looksLikeMultipartNeeded) {
        throw Exception('Inference failed: ${resp.statusCode} ${resp.body}');
      }
    } catch (_) {
      // continue to multipart fallback
    }

    // Second attempt: multipart/form-data with field name 'file'
    final request = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: imageFile.uri.pathSegments.isNotEmpty
              ? imageFile.uri.pathSegments.last
              : 'image.jpg',
          contentType: MediaType('image', _inferImageSubtype(imageFile.path)),
        ),
      );

    final streamed = await request.send().timeout(timeout);
    final resp2 = await http.Response.fromStream(streamed);
    if (resp2.statusCode >= 200 && resp2.statusCode < 300) {
      return jsonDecode(resp2.body) as Map<String, dynamic>;
    }
    throw Exception('Inference failed (multipart): ${resp2.statusCode} ${resp2.body}');
  }

  Future<Map<String, dynamic>> inferImageUrl(
      String imageUrl, {
        Map<String, String>? params,
        Duration timeout = const Duration(seconds: 30),
      }) async {
    final merged = {'image': imageUrl, ...?params};
    final uri = _buildUri(extraParams: merged);

    final resp = await http
        .post(
      uri,
      headers: {'Accept': 'application/json'},
    )
        .timeout(timeout);

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } else {
      throw Exception('Inference failed: ${resp.statusCode} ${resp.body}');
    }
  }
}


String _inferImageSubtype(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return 'png';
  if (lower.endsWith('.bmp')) return 'bmp';
  if (lower.endsWith('.webp')) return 'webp';
  if (lower.endsWith('.gif')) return 'gif';
  return 'jpeg';
}