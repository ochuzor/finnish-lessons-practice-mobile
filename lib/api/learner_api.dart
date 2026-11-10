import 'dart:convert';

import 'package:http/http.dart' as http;

typedef IdTokenProvider = Future<String?> Function();

class BackendUser {
  const BackendUser({
    required this.id,
    required this.username,
    required this.isOwner,
  });

  factory BackendUser.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final username = json['username'];
    final isOwner = json['is_owner'];

    if (id is! int || username is! String || isOwner is! bool) {
      throw const FormatException(
        'The server returned an invalid user profile.',
      );
    }

    return BackendUser(id: id, username: username, isOwner: isOwner);
  }

  final int id;
  final String username;
  final bool isOwner;
}

abstract interface class LearnerApi {
  Future<BackendUser> getCurrentUser();
}

class LearnerApiException implements Exception {
  const LearnerApiException(this.detail, {this.statusCode});

  final String detail;
  final int? statusCode;

  @override
  String toString() => detail;
}

class HttpLearnerApi implements LearnerApi {
  HttpLearnerApi({
    required String baseUrl,
    required this.idTokenProvider,
    http.Client? client,
  }) : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
       _client = client ?? http.Client();

  final String _baseUrl;
  final IdTokenProvider idTokenProvider;
  final http.Client _client;

  @override
  Future<BackendUser> getCurrentUser() async {
    final response = await _get('/api/auth/me');
    final user = response['user'];
    if (user is! Map<String, dynamic>) {
      throw const LearnerApiException(
        'The server returned an invalid account response.',
      );
    }

    try {
      return BackendUser.fromJson(user);
    } on FormatException catch (error) {
      throw LearnerApiException(error.message);
    }
  }

  Future<Map<String, dynamic>> _get(String path) async {
    if (_baseUrl.isEmpty) {
      throw const LearnerApiException(
        'API_BASE_URL is missing. Start the app with the production API URL.',
      );
    }

    final token = await idTokenProvider();
    if (token == null || token.isEmpty) {
      throw const LearnerApiException(
        'Your sign-in session is unavailable. Sign out and sign in again.',
      );
    }

    late http.Response response;
    try {
      response = await _client.get(
        Uri.parse('$_baseUrl$path'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
    } on Exception {
      throw const LearnerApiException(
        'Could not reach the Finnish Lessons server. Check your connection and try again.',
      );
    }

    final body = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = body['detail'];
      throw LearnerApiException(
        detail is String && detail.isNotEmpty
            ? detail
            : 'The server could not complete the request.',
        statusCode: response.statusCode,
      );
    }

    return body;
  }

  Map<String, dynamic> _decodeObject(String source) {
    if (source.isEmpty) return const {};

    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // The common error below gives the user more useful context.
    }

    throw const LearnerApiException(
      'The server returned an unreadable response.',
    );
  }
}
