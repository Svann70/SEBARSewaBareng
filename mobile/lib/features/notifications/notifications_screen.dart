import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/state.dart';

/// Notifikasi in-app: perubahan porsi, masa bebas, kick, booking, dan denda.
/// Dibuka = semua ditandai terbaca.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final notifier = ref.read(notificationsProvider.notifier);
    final error = await notifier.refresh();
    if (!mounted) return;
    setState(() {
      _error = error;
      _loading = false;
    });
    if (error == null) await notifier.markAllRead();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(notificationsProvider).items;
    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi')),
      body: RefreshIndicator(
        color: C.primary,
        onRefresh: _load,
        child: ListView(
          padding: kScreenPad,
          children: [
            if (_loading && items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && items.isEmpty)
              EmptyState(
                icon: Icons.error_outline,
                title: 'Notifikasi gagal dimuat',
                message: _error!,
                action: GhostButton(
                  label: 'Coba lagi',
                  icon: Icons.refresh,
                  onPressed: _load,
                ),
              )
            else if (items.isEmpty)
              const EmptyState(
                icon: Icons.notifications_none,
                title: 'Belum ada notifikasi',
                message: 'Kabar soal room dan porsi patunganmu muncul di sini.',
              )
            else
              for (final n in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    n.read ? Icons.notifications_none : Icons.notifications,
                    color: n.read ? C.faint : C.primary,
                  ),
                  title: Text(n.message, style: T.body),
                  subtitle: Text(
                    '${formatDate(wib(n.createdAt))}, ${formatTime(wib(n.createdAt))}',
                    style: T.caption,
                  ),
                  onTap: n.lobbyId == null
                      ? null
                      : () => context.push('/lobby/${n.lobbyId}'),
                ),
          ],
        ),
      ),
    );
  }
}
