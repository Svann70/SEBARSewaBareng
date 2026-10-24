import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sebar/app.dart';
import 'package:sebar/data/api.dart';
import 'package:sebar/data/state.dart';
import 'package:sebar/features/auth/login_screen.dart';

http.Response _json(int status, Object body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Future<Object?> _caught(Future<Object?> future) async {
  try {
    await future;
    return null;
  } catch (error) {
    return error;
  }
}

final _session = {
  'accessToken': 'a1',
  'refreshToken': 'r1',
  'user': {'id': 'u1', 'role': 'PLAYER'},
};

void main() {
  group('authRedirect', () {
    test('tanpa sesi hanya login/daftar yang terbuka', () {
      expect(authRedirect(null, '/login'), isNull);
      expect(authRedirect(null, '/register'), isNull);
      for (final path in [
        '/home',
        '/wallet',
        '/lobby/x',
        '/venue',
        '/tickets',
      ]) {
        expect(authRedirect(null, path), '/login', reason: path);
      }
    });

    test('sudah masuk tidak bisa kembali ke login', () {
      expect(authRedirect(AccountRole.player, '/login'), '/home');
      expect(authRedirect(AccountRole.venue, '/register'), '/venue');
    });

    test('tiap peran hanya di areanya', () {
      expect(authRedirect(AccountRole.player, '/home'), isNull);
      expect(authRedirect(AccountRole.player, '/venue'), '/home');
      expect(authRedirect(AccountRole.player, '/venue/analytics'), '/home');
      expect(authRedirect(AccountRole.venue, '/venue/analytics'), isNull);
      expect(authRedirect(AccountRole.venue, '/home'), '/venue');
      expect(authRedirect(AccountRole.venue, '/create'), '/venue');
    });
  });

  group('ApiClient sesi', () {
    test(
      'refresh ditolak server: sesi dihapus dan callback dipanggil',
      () async {
        var expired = 0;
        final client = ApiClient(
          baseUrl: 'http://api',
          client: MockClient(
            (req) async => switch (req.url.path) {
              '/auth/login' => _json(200, _session),
              '/auth/refresh' => _json(401, {
                'error': {'code': 'UNAUTHORIZED', 'message': 'x'},
              }),
              _ => _json(401, {
                'error': {'code': 'UNAUTHORIZED', 'message': 'x'},
              }),
            },
          ),
        )..onSessionExpired = () => expired++;

        await client.login('a@b.c', 'password1');
        expect(client.hasSession, isTrue);
        await expectLater(
          client.get('/me/wallet'),
          throwsA(
            isA<ApiException>().having(
              (e) => e.code,
              'code',
              'SESSION_EXPIRED',
            ),
          ),
        );
        expect(client.hasSession, isFalse);
        expect(client.user, isNull);
        expect(expired, 1);
      },
    );

    test('jaringan putus saat refresh: sesi tetap ada', () async {
      var expired = 0;
      final client = ApiClient(
        baseUrl: 'http://api',
        client: MockClient((req) async {
          if (req.url.path == '/auth/login') return _json(200, _session);
          if (req.url.path == '/auth/refresh') {
            throw http.ClientException('offline');
          }
          return _json(401, {
            'error': {'code': 'UNAUTHORIZED', 'message': 'x'},
          });
        }),
      )..onSessionExpired = () => expired++;

      await client.login('a@b.c', 'password1');
      await expectLater(
        client.get('/me/wallet'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'NETWORK')),
      );
      expect(client.hasSession, isTrue);
      expect(expired, 0);
    });

    test(
      'password lama salah (401 setelah refresh sukses): tetap masuk',
      () async {
        var expired = 0;
        final client = ApiClient(
          baseUrl: 'http://api',
          client: MockClient(
            (req) async => switch (req.url.path) {
              '/auth/login' => _json(200, _session),
              '/auth/refresh' => _json(200, {
                'accessToken': 'a2',
                'refreshToken': 'r2',
              }),
              _ => _json(401, {
                'error': {
                  'code': 'UNAUTHORIZED',
                  'message': 'Password saat ini salah.',
                },
              }),
            },
          ),
        )..onSessionExpired = () => expired++;

        await client.login('a@b.c', 'password1');
        await expectLater(
          client.changePassword(current: 'salah123', next: 'baru12345'),
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'message',
              'Password saat ini salah.',
            ),
          ),
        );
        expect(client.hasSession, isTrue);
        expect(expired, 0);
      },
    );

    test('refresh 403 juga mengakhiri sesi', () async {
      var expired = 0;
      final client = ApiClient(
        baseUrl: 'http://api',
        client: MockClient(
          (req) async => switch (req.url.path) {
            '/auth/login' => _json(200, _session),
            '/auth/refresh' => _json(403, {
              'error': {'code': 'FORBIDDEN', 'message': 'x'},
            }),
            _ => _json(401, {
              'error': {'code': 'UNAUTHORIZED', 'message': 'x'},
            }),
          },
        ),
      )..onSessionExpired = () => expired++;

      await client.login('a@b.c', 'password1');
      await expectLater(client.get('/me'), throwsA(isA<ApiException>()));
      expect(client.hasSession, isFalse);
      expect(expired, 1);
    });

    test('dua request serentak: satu refresh, satu callback', () async {
      var refreshes = 0, expired = 0;
      final client = ApiClient(
        baseUrl: 'http://api',
        client: MockClient((req) async {
          if (req.url.path == '/auth/login') return _json(200, _session);
          if (req.url.path == '/auth/refresh') {
            refreshes++;
            await Future<void>.delayed(const Duration(milliseconds: 10));
            return _json(401, {
              'error': {'code': 'UNAUTHORIZED', 'message': 'x'},
            });
          }
          return _json(401, {
            'error': {'code': 'UNAUTHORIZED', 'message': 'x'},
          });
        }),
      )..onSessionExpired = () => expired++;

      await client.login('a@b.c', 'password1');
      final results = await Future.wait([
        _caught(client.get('/me/wallet')),
        _caught(client.get('/me/bookings')),
      ]);
      expect(results, everyElement(isA<ApiException>()));
      expect(refreshes, 1);
      expect(expired, 1);
    });

    test('refresh 200 tanpa token (portal Wi-Fi): sesi tidak diubah', () async {
      var expired = 0;
      final client = ApiClient(
        baseUrl: 'http://api',
        client: MockClient(
          (req) async => switch (req.url.path) {
            '/auth/login' => _json(200, _session),
            '/auth/refresh' => http.Response('<html>login wifi</html>', 200),
            _ => _json(401, {
              'error': {'code': 'UNAUTHORIZED', 'message': 'x'},
            }),
          },
        ),
      )..onSessionExpired = () => expired++;

      await client.login('a@b.c', 'password1');
      await expectLater(
        client.get('/me'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'NETWORK')),
      );
      expect(client.hasSession, isTrue);
      expect(expired, 0);
    });

    test('login 200 tanpa token ditolak', () async {
      final client = ApiClient(
        baseUrl: 'http://api',
        client: MockClient((_) async => http.Response('<html></html>', 200)),
      );
      await expectLater(
        client.login('a@b.c', 'password1'),
        throwsA(isA<ApiException>()),
      );
      expect(client.hasSession, isFalse);
    });

    test('logout saat refresh berjalan: hasil refresh dibuang', () async {
      var expired = 0;
      final refreshGate = Completer<void>();
      final client = ApiClient(
        baseUrl: 'http://api',
        client: MockClient((req) async {
          switch (req.url.path) {
            case '/auth/login':
              return _json(200, _session);
            case '/auth/logout':
              return http.Response('', 204);
            case '/auth/refresh':
              await refreshGate.future;
              return _json(200, {'accessToken': 'a2', 'refreshToken': 'r2'});
          }
          return _json(401, {
            'error': {'code': 'UNAUTHORIZED', 'message': 'x'},
          });
        }),
      )..onSessionExpired = () => expired++;

      await client.login('a@b.c', 'password1');
      final pending = _caught(client.get('/me'));
      await Future<void>.delayed(Duration.zero);
      await client.logout();
      refreshGate.complete();
      expect(await pending, isA<ApiException>());
      expect(
        client.hasSession,
        isFalse,
        reason: 'token lama tidak boleh kembali',
      );
      expect(expired, 0);
    });
  });

  test('sesi berakhir: peran dikosongkan dan data akun direset', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(authProvider.notifier).login(AccountRole.player);
    container.read(walletProvider.notifier).topUp(5000);
    final before = container.read(walletProvider).balance;

    api.onSessionExpired!();
    await Future<void>.delayed(Duration.zero);

    expect(container.read(authProvider), isNull);
    expect(container.read(walletProvider).balance, before - 5000);
    expect(
      container.read(authProvider.notifier).takeSessionNotice(),
      isNotNull,
    );
  });

  testWidgets('buka /home tanpa login dilempar ke layar masuk', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const SebarApp()),
    );
    await tester.pumpAndSettle();

    final router = container.read(routerProvider);
    for (final path in ['/home', '/venue', '/tickets']) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget, reason: path);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/login',
        reason: path,
      );
    }
  });

  testWidgets('sesi dicabut saat di beranda: kembali ke layar masuk', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const SebarApp()),
    );
    container.read(authProvider.notifier).login(AccountRole.player);
    final GoRouter router = container.read(routerProvider);
    router.go('/home');
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/home');

    api.onSessionExpired!();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Sesi berakhir. Silakan masuk lagi.'), findsOneWidget);
  });
}
