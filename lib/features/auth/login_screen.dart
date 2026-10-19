import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/state.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController(text: 'raka@sebar.app');
  final _password = TextEditingController(text: 'password123');
  bool _register = false;
  AccountRole _role = AccountRole.player;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _pickRole(AccountRole role) {
    setState(() {
      _role = role;
      _email.text = role == AccountRole.player
          ? 'raka@sebar.app'
          : 'admin@ctra-arena.id';
      _register = false;
    });
  }

  void _submit() {
    if (_password.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password minimal 8 karakter.')),
      );
      return;
    }
    ref.read(authProvider.notifier).login(_role);
    context.go(_role.home);
  }

  @override
  Widget build(BuildContext context) {
    final isVenue = _role == AccountRole.venue;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF7A93), C.pinkDeep],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.sports_tennis,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'SEBAR',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: C.ink,
                  ),
                ),
                const Spacer(),
                const Pill('Satu app, dua akun', background: C.surfaceAlt),
              ],
            ),
            const SizedBox(height: 26),
            Text(
              isVenue ? 'Kelola lapangan,\nbukan cari lawan.' : 'Sewa lapangan,\nbayar patungan.',
              style: T.display,
            ),
            const SizedBox(height: 8),
            Text(
              isVenue
                  ? 'Akun mitra terpisah dari akun pemain. Slot, harga, dan '
                        'pencairan ada di dashboard venue.'
                  : 'Satu room, satu harga per orang. Dana dikunci sejak join, '
                        'jadi tidak ada yang kabur setelah jadwal terkunci.',
              style: T.body,
            ),
            const SizedBox(height: 20),
            _RoleSwitch(role: _role, onPick: _pickRole),
            const SizedBox(height: 18),
            SportPanel(
              gradient: isVenue
                  ? const [Color(0xFF9C90FF), Color(0xFF6C5CE0)]
                  : const [Color(0xFFFF7A93), C.pinkDeep],
              height: 118,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Pill(
                          isVenue ? 'Pencairan bulan ini' : 'Split bill otomatis',
                          background: Colors.white24,
                        ),
                        const SizedBox(height: 9),
                        Text(
                          isVenue ? 'Rp12.750.000' : 'Rp50.000',
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.1,
                            height: 1,
                            color: C.ink,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          isVenue
                              ? '128 booking · okupansi 78%'
                              : 'GOR C-Tra · 8 orang · 2 jam',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isVenue ? Icons.insights : Icons.groups_2_outlined,
                    size: 34,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            LabeledField(
              label: isVenue ? 'Email venue' : 'Email',
              controller: _email,
              hint: 'nama@email.com',
              keyboard: TextInputType.emailAddress,
              prefixIcon: Icons.alternate_email,
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: 'Password',
              controller: _password,
              hint: 'Minimal 8 karakter',
              obscure: true,
              prefixIcon: Icons.lock_outline,
            ),
            const SizedBox(height: 18),
            SebarButton(
              label: _register
                  ? (isVenue ? 'Daftarkan venue' : 'Buat akun')
                  : (isVenue ? 'Masuk dashboard venue' : 'Masuk'),
              onPressed: _submit,
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => setState(() => _register = !_register),
                child: Text(
                  _register
                      ? 'Sudah punya akun? Masuk'
                      : 'Belum punya akun? Daftar',
                  style: const TextStyle(
                    color: C.pink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Center(
              child: Text(
                isVenue
                    ? 'Akun venue tidak bisa join room pemain.'
                    : 'Mau kelola lapangan? Pilih Venue di atas.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: C.faint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pemilih peran: dua kartu, bukan dropdown — peran menentukan seluruh app.
class _RoleSwitch extends StatelessWidget {
  const _RoleSwitch({required this.role, required this.onPick});

  final AccountRole role;
  final ValueChanged<AccountRole> onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final r in AccountRole.values) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onPick(r),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: role == r ? C.pink : C.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: role == r ? C.pink : C.line),
                ),
                child: Row(
                  children: [
                    Icon(
                      r.icon,
                      size: 17,
                      color: role == r ? Colors.white : C.muted,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: role == r ? Colors.white : C.ink,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            r == AccountRole.player ? 'Main' : 'Kelola',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: role == r ? Colors.white70 : C.faint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (r != AccountRole.values.last) const SizedBox(width: 10),
        ],
      ],
    );
  }
}
