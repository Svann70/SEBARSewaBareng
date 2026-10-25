import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Error dari API atau jaringan. [message] sudah siap ditampilkan ke pengguna.
class ApiException {
  const ApiException(this.code, this.message, {this.status = 0});

  final String code;
  final String message;
  final int status;

  @override
  String toString() => message;
}

/// Klien HTTP tipis ke backend SEBAR.
///
/// Token disimpan di memori: sesi hilang saat app ditutup. Saat butuh sesi
/// tahan restart, simpan refresh token di secure storage lalu panggil
/// [restore] sebelum layar pertama.
class ApiClient {
  ApiClient({String? baseUrl, http.Client? client})
    : baseUrl = baseUrl ?? _defaultBase,
      _client = client ?? http.Client();

  static const _timeout = Duration(seconds: 15);
  static const _envUrl = String.fromEnvironment('SEBAR_API_URL');

  static String get _defaultBase {
    if (_envUrl.isNotEmpty) return _envUrl;
    // Emulator Android memakai alias host 10.0.2.2; web/desktop localhost.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  final String baseUrl;
  final http.Client _client;

  String? _accessToken;
  String? _refreshToken;
  String? userId;
  Map<String, dynamic>? user;
  Future<void>? _refreshing;

  /// Naik setiap sesi diganti/dihapus. Hasil refresh yang selesai setelah
  /// sesinya berganti (logout, akun lain) dibuang.
  int _generation = 0;
  int _refreshingGeneration = -1;

  static const _badResponse = ApiException(
    'NETWORK',
    'Respons server tidak valid. Cek koneksi lalu coba lagi.',
  );

  /// Dipanggil saat server menolak refresh token (sesi dicabut/kedaluwarsa).
  /// Gangguan jaringan tidak memicu ini.
  void Function()? onSessionExpired;

  bool get hasSession => _refreshToken != null;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  // ── Auth ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = _asMap(
      await _send(
        'POST',
        '/auth/login',
        body: {'email': email, 'password': password},
        auth: false,
      ),
    );
    _applySession(data);
    return data;
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
    required String role,
    Map<String, dynamic>? venue,
  }) async {
    final data = _asMap(
      await _send(
        'POST',
        '/auth/register',
        body: {
          'email': email,
          'password': password,
          'fullName': fullName,
          'role': role,
          'venue': ?venue,
        },
        auth: false,
      ),
    );
    _applySession(data);
    return data;
  }

  Future<void> forgotPassword(String email) => _send(
    'POST',
    '/auth/forgot-password',
    body: {'email': email},
    auth: false,
  );

  Future<void> logout() async {
    final token = _refreshToken;
    try {
      if (token != null) {
        await _send(
          'POST',
          '/auth/logout',
          body: {'refreshToken': token},
          auth: false,
        );
      }
    } on ApiException {
      // Sesi lokal tetap dibersihkan walau server tidak bisa dihubungi.
    } finally {
      _clearSession();
    }
  }

  void _clearSession() {
    _generation++;
    _accessToken = null;
    _refreshToken = null;
    userId = null;
    user = null;
  }

  // ── Profil ──────────────────────────────────────────────────────────────

  /// PATCH /me: field yang tidak dikirim tidak berubah; [clearPhone] menghapus nomor.
  Future<Map<String, dynamic>> updateMe({
    String? fullName,
    String? phone,
    bool clearPhone = false,
  }) async {
    final body = <String, dynamic>{
      'fullName': ?fullName,
      if (clearPhone) 'phone': null,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    };
    final data = _asMap(await _send('PATCH', '/me', body: body));
    _applyUser(data);
    return data;
  }

  /// POST /me/password: sukses memicu 204, lalu seluruh sesi dicabut server —
  /// pemanggil wajib signOut dan kembali ke layar masuk.
  Future<void> changePassword({
    required String current,
    required String next,
  }) => _send(
    'POST',
    '/me/password',
    body: {'currentPassword': current, 'newPassword': next},
  );

  void _applyUser(Map<String, dynamic> data) {
    user = data;
    userId = data['id'] as String?;
  }

  void _applySession(Map<String, dynamic> data) {
    final access = data['accessToken'], refresh = data['refreshToken'];
    if (access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.isEmpty) {
      throw _badResponse;
    }
    _generation++;
    _accessToken = access;
    _refreshToken = refresh;
    final u = data['user'];
    if (u is Map) {
      user = _asMap(u);
      userId = user?['id'] as String?;
    }
  }

  Future<void> _refreshTokens() {
    final pending = _refreshing;
    // Refresh milik sesi lama (sebelum logout/ganti akun) tidak dipakai ulang.
    if (pending != null && _refreshingGeneration == _generation) return pending;
    final future = _doRefresh();
    _refreshing = future;
    _refreshingGeneration = _generation;
    return future.whenComplete(() {
      if (identical(_refreshing, future)) _refreshing = null;
    });
  }

  Future<void> _doRefresh() async {
    final token = _refreshToken;
    final generation = _generation;
    if (token == null) {
      throw const ApiException(
        'UNAUTHORIZED',
        'Sesi sudah berakhir.',
        status: 401,
      );
    }
    const stale = ApiException(
      'UNAUTHORIZED',
      'Sesi sudah berganti.',
      status: 401,
    );
    dynamic payload;
    try {
      payload = await _send(
        'POST',
        '/auth/refresh',
        body: {'refreshToken': token},
        auth: false,
      );
    } on ApiException catch (error) {
      if (generation != _generation) throw stale;
      // Hanya penolakan dari server yang mengakhiri sesi; timeout/offline
      // membiarkan token agar request berikutnya bisa mencoba lagi.
      if (error.status == 401 || error.status == 403) {
        _clearSession();
        onSessionExpired?.call();
        throw const ApiException(
          'SESSION_EXPIRED',
          'Sesi berakhir. Silakan masuk lagi.',
          status: 401,
        );
      }
      rethrow;
    }
    if (generation != _generation) throw stale;
    final data = _asMap(payload);
    final access = data['accessToken'], refresh = data['refreshToken'];
    // 200 tanpa token (mis. portal Wi-Fi) bukan penolakan: sesi dibiarkan.
    if (access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.isEmpty) {
      throw _badResponse;
    }
    _accessToken = access;
    _refreshToken = refresh;
  }

  // ── Endpoint publik ─────────────────────────────────────────────────────

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  /// Kirim berkas mentah (foto). Jenis berkas dicek server dari isinya.
  Future<dynamic> postBytes(String path, List<int> bytes, String contentType) =>
      _send('POST', path, bytes: bytes, headers: {'Content-Type': contentType});

  Future<dynamic> topup(int amount, String idempotencyKey) => _send(
    'POST',
    '/me/wallet/topup',
    body: {'amount': amount},
    headers: {'Idempotency-Key': idempotencyKey},
  );

  Future<dynamic> withdraw({
    required int amount,
    required String bankCode,
    required String accountNumber,
    required String accountName,
    required String idempotencyKey,
  }) => _send(
    'POST',
    '/me/wallet/withdrawals',
    body: {
      'amount': amount,
      'bankCode': bankCode,
      'accountNumber': accountNumber,
      'accountName': accountName,
    },
    headers: {'Idempotency-Key': idempotencyKey},
  );

  // ── Transport ───────────────────────────────────────────────────────────

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    List<int>? bytes,
    Map<String, String>? headers,
    bool auth = true,
    bool retry = true,
  }) async {
    final uri = Uri.parse(
      '$baseUrl$path',
    ).replace(queryParameters: query == null || query.isEmpty ? null : query);
    final request = http.Request(method, uri)
      ..headers.addAll({..._headers, ...?headers});
    if (body != null) request.body = jsonEncode(body);
    if (bytes != null) request.bodyBytes = bytes;

    http.Response response;
    try {
      final streamed = await _client.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed).timeout(_timeout);
    } on TimeoutException {
      throw const ApiException(
        'NETWORK',
        'Server tidak merespons. Coba lagi sebentar.',
      );
    } on http.ClientException {
      throw ApiException(
        'NETWORK',
        'Tidak bisa menghubungi $baseUrl. Jalankan backend dan cek koneksi.',
      );
    }

    final payload = _decode(response.body);
    if (response.statusCode == 401 && auth && retry && _refreshToken != null) {
      await _refreshTokens();
      return _send(
        method,
        path,
        query: query,
        body: body,
        bytes: bytes,
        headers: headers,
        auth: auth,
        retry: false,
      );
    }
    if (response.statusCode >= 400) throw _error(response.statusCode, payload);
    return payload;
  }

  static dynamic _decode(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  static ApiException _error(int status, dynamic payload) {
    final error = payload is Map ? payload['error'] : null;
    if (error is Map) {
      final details = error['details'];
      final first = details is List && details.isNotEmpty
          ? details.first
          : null;
      final detail = first is Map ? first['message'] as String? : null;
      final message =
          error['message'] as String? ?? 'Permintaan gagal ($status).';
      return ApiException(
        error['code'] as String? ?? 'HTTP_$status',
        detail == null ? message : '$message $detail',
        status: status,
      );
    }
    return ApiException(
      'HTTP_$status',
      'Permintaan gagal ($status).',
      status: status,
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return value.cast<String, dynamic>();
    return <String, dynamic>{};
  }
}

/// Satu instance untuk seluruh aplikasi.
final api = ApiClient();