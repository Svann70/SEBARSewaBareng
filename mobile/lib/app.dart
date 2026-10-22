import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'core/widgets.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/booking/ticket_screen.dart';
import 'features/booking/tickets_screen.dart';
import 'features/community/community_screen.dart';
import 'features/create/create_lobby_screen.dart';
import 'features/home/home_screen.dart';
import 'features/lobby/lobby_detail_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/rooms/rooms_screen.dart';
import 'features/venue/venue_shell.dart';
import 'features/venue/venue_tabs.dart';
import 'features/wallet/wallet_screen.dart';

final _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
    GoRoute(path: '/home', builder: (_, _) => const HomeShell()),
    GoRoute(path: '/rooms', builder: (_, _) => const RoomsScreen()),
    GoRoute(
      path: '/lobby/:id',
      builder: (_, s) => LobbyDetailScreen(id: s.pathParameters['id']!),
    ),
    GoRoute(path: '/create', builder: (_, _) => const CreateLobbyScreen()),
    GoRoute(
      path: '/ticket/:id',
      builder: (_, s) => TicketScreen(id: s.pathParameters['id']!),
    ),
    GoRoute(path: '/venue', builder: (_, _) => const VenueShell()),
    GoRoute(
      path: '/venue/analytics',
      builder: (_, _) => const VenueAnalyticsScreen(),
    ),
    GoRoute(path: '/community', builder: (_, _) => const CommunityScreen()),
  ],
);

class SebarApp extends StatelessWidget {
  const SebarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SEBAR',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: _router,
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

  /// Tab dibangun saat pertama dibuka, lalu dijaga hidup.
  /// Menghemat frame pertama: hanya Home yang di-layout.
  final _visited = <int>{0};

  static const _pages = [
    HomeScreen(),
    TicketsScreen(),
    WalletScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < _pages.length; i++)
            _visited.contains(i)
                ? RepaintBoundary(child: _pages[i])
                : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: DockNav(
        index: _index,
        onSelect: (i) => setState(() {
          _index = i;
          _visited.add(i);
        }),
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
  });

  final IconData icon;
  final VoidCallback? onTap;

  /// Titik notifikasi kecil di sudut kanan atas.
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
  }
}
