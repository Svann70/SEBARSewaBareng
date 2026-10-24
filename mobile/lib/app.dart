import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'core/widgets.dart';
import 'data/state.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/booking/ticket_screen.dart';
import 'features/booking/tickets_screen.dart';
import 'features/community/community_screen.dart';
import 'features/create/create_lobby_screen.dart';
import 'features/home/home_screen.dart';
import 'features/lobby/lobby_detail_screen.dart';
import 'features/profile/edit_profile_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/rooms/rooms_screen.dart';
import 'features/venue/court_form.dart';
import 'features/venue/venue_shell.dart';
import 'features/venue/venue_tabs.dart';
import 'features/wallet/wallet_screen.dart';

/// Rute yang boleh dibuka tanpa login.
const _publicRoutes = {'/login', '/register'};

/// Tujuan redirect untuk [location], atau null bila boleh dibuka.
/// Tanpa sesi semua rute selain login/daftar ditolak; tiap peran hanya
/// boleh di area miliknya (venue di /venue, pemain di luar /venue).
String? authRedirect(AccountRole? role, String location) {
  final isPublic = _publicRoutes.contains(location);
  if (role == null) return isPublic ? null : '/login';
  if (isPublic) return role.home;
  final inVenueArea = location == '/venue' || location.startsWith('/venue/');
  if ((role == AccountRole.venue) != inVenueArea) return role.home;
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final role = ValueNotifier<AccountRole?>(ref.read(authProvider));
  ref.listen(authProvider, (_, next) => role.value = next);
  final router = GoRouter(
    initialLocation: '/login',
    refreshListenable: role,
    redirect: (_, state) => authRedirect(role.value, state.matchedLocation),
    routes: _routes,
  );
  ref.onDispose(() {
    router.dispose();
    role.dispose();
  });
  return router;
});

final _routes = <RouteBase>[
  GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
  GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
  GoRoute(path: '/home', builder: (_, _) => const HomeShell()),
  GoRoute(path: '/rooms', builder: (_, _) => const RoomsScreen()),
  GoRoute(path: '/profile/edit', builder: (_, _) => const EditProfileScreen()),
  GoRoute(
    path: '/lobby/:id',
    builder: (_, s) => LobbyDetailScreen(id: s.pathParameters['id']!),
  ),
  GoRoute(path: '/create', builder: (_, _) => const CreateLobbyScreen()),
  GoRoute(
    path: '/tickets',
    builder: (_, _) => const Scaffold(body: TicketsScreen()),
  ),
  GoRoute(
    path: '/ticket/:id',
    builder: (_, s) => TicketScreen(id: s.pathParameters['id']!),
  ),
  GoRoute(path: '/venue', builder: (_, _) => const VenueShell()),
  GoRoute(
    path: '/venue/analytics',
    builder: (_, _) => const VenueAnalyticsScreen(),
  ),
  GoRoute(path: '/venue/court/new', builder: (_, _) => const CourtFormScreen()),
  GoRoute(
    path: '/venue/court/:id',
    builder: (_, s) => CourtFormScreen(courtId: s.pathParameters['id']),
  ),
  GoRoute(path: '/community', builder: (_, _) => const CommunityScreen()),
];

class SebarApp extends ConsumerWidget {
  const SebarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'SEBAR',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = [
    HomeScreen(),
    TicketsScreen(),
    WalletScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Struktur anak tetap (bug Flutter 3.41 semantics parentDataDirty
          // saat tukar tipe/jumlah child saat runtime); toggle via Offstage.
          for (var i = 0; i < _pages.length; i++)
            Offstage(
              offstage: _index != i,
              child: RepaintBoundary(child: _pages[i]),
            ),
        ],
      ),
      bottomNavigationBar: DockNav(
        index: _index,
        onSelect: (i) => setState(() => _index = i),
        onCreate: () => context.push('/create'),
      ),
    );
  }
}

/// Header halaman dengan tombol kembali bulat.
class RoundBackHeader extends StatelessWidget {
  const RoundBackHeader({super.key, this.title, this.actions});

  final String? title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          CircleIconButton(
            icon: Icons.arrow_back,
            tooltip: 'Kembali',
            onTap: () => context.canPop() ? context.pop() : context.go('/home'),
          ),
          const SizedBox(width: 12),
          if (title != null)
            Expanded(child: Text(title!, style: T.h2))
          else
            const Spacer(),
          ...?actions,
        ],
      ),
    );
  }
}

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.badge = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;

  /// Titik notifikasi kecil di sudut kanan atas.
  final bool badge;

  /// Label untuk layar pembaca; ikon saja tidak terbaca.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: C.surface,
            shape: const CircleBorder(side: BorderSide(color: C.line)),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 42,
                height: 42,
                child: Icon(icon, size: 18, color: C.ink),
              ),
            ),
          ),
          if (badge)
            Positioned(
              right: 9,
              top: 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: C.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: C.bg, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
