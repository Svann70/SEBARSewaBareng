import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/state.dart';
import 'login_screen.dart';

/// Layar terpisah dari [LoginScreen] supaya calon pengguna tidak bingung
/// antara masuk dan mendaftar.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _venueName = TextEditingController();
  final _venueAddress = TextEditingController();
  final _venueCity = TextEditingController();
  AccountRole _role = AccountRole.player;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _venueName.dispose();
    _venueAddress.dispose();
    _venueCity.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _email.text.trim();
    if (_name.text.trim().length < 3) {
      setState(() => _error = 'Nama minimal 3 karakter.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Format email belum benar.');
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _error = 'Password minimal 8 karakter.');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'Konfirmasi password tidak sama.');
      return;
    }
    final role = _role;
    if (role == AccountRole.venue) {
      if (_venueName.text.trim().length < 3) {
        setState(() => _error = 'Nama venue minimal 3 karakter.');
        return;
      }
      if (_venueAddress.text.trim().length < 5) {
        setState(() => _error = 'Alamat venue minimal 5 karakter.');
        return;
      }
      if (_venueCity.text.trim().length < 2) {
        setState(() => _error = 'Kota venue wajib diisi.');
        return;
      }
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    final error = await ref
        .read(authProvider.notifier)
        .signUp(
          email: email,
          password: _password.text,
          fullName: _name.text.trim(),
          role: role,
          venue: role == AccountRole.venue
              ? {
                  'name': _venueName.text.trim(),
                  'address': _venueAddress.text.trim(),
                  'city': _venueCity.text.trim(),
                }
              : null,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Akun ${_name.text.trim()} siap dipakai.')),
    );
    // Akun venue baru langsung ke form "Atur venue" (diisi sekali di awal).
    context.go(role == AccountRole.venue ? '/venue/setup' : role.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            const BrandMark(),
            const SizedBox(height: 28),
            const Text('Daftar', style: T.display),
            const SizedBox(height: 8),
            const Text(
              'Isi data berikut, lalu kamu langsung bisa cari dan buat room.',
              style: T.body,
            ),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Daftar sebagai', style: T.small),
            ),
            const SizedBox(height: 8),
            Segmented<AccountRole>(
              options: AccountRole.values,
              value: _role,
              labelOf: (role) =>
                  role == AccountRole.player ? 'Pemain' : 'Mitra venue',
              onChanged: (role) => setState(() => _role = role),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(_role.hint, style: T.caption),
            ),
            const SizedBox(height: 14),
            LabeledField(
              label: 'Nama lengkap',
              controller: _name,
              hint: 'Nama yang tampil ke teman satu room',
              prefixIcon: Icons.person_outline,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            LabeledField(
              label: 'Email',
              controller: _email,
              hint: 'nama@email.com',
              keyboard: TextInputType.emailAddress,
              prefixIcon: Icons.alternate_email,
            ),
            if (_role == AccountRole.venue) ...[
              const SizedBox(height: 14),
              LabeledField(
                label: 'Nama venue',
                controller: _venueName,
                hint: 'Contoh: GOR C-Tra',
                prefixIcon: Icons.storefront_outlined,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 14),
              LabeledField(
                label: 'Alamat venue',
                controller: _venueAddress,
                hint: 'Jalan dan nomor',
                prefixIcon: Icons.location_on_outlined,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 14),
              LabeledField(
                label: 'Kota',
                controller: _venueCity,
                hint: 'Contoh: Bandung',
                prefixIcon: Icons.place_outlined,
                textCapitalization: TextCapitalization.words,
              ),
            ],
            const SizedBox(height: 14),
            LabeledField(
              label: 'Password',
              controller: _password,
              hint: 'Minimal 8 karakter',
              obscure: true,
              prefixIcon: Icons.lock_outline,
            ),
            const SizedBox(height: 14),
            LabeledField(
              label: 'Ulangi password',
              controller: _confirm,
              hint: 'Ketik ulang password',
              obscure: true,
              prefixIcon: Icons.lock_reset_outlined,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, size: 16, color: C.danger),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: C.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            SebarButton(
              label: _busy ? 'Mendaftar…' : 'Buat akun',
              onPressed: _busy ? null : _submit,
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Sudah punya akun?', style: T.small),
                TextButton(
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/login'),
                  child: const Text('Masuk'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Dengan mendaftar, kamu setuju dana room dikunci saat join dan '
              'aturan pembatalan berlaku.',
              textAlign: TextAlign.center,
              style: T.caption,
            ),
          ],
        ),
      ),
    );
  }
}
