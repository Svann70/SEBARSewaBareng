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
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
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
    setState(() => _error = null);
    final role = roleForEmail(email);
    ref.read(authProvider.notifier).login(role);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Akun ${_name.text.trim()} siap dipakai.')),
    );
    context.go(role.home);
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
            SebarButton(label: 'Buat akun', onPressed: _submit),
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
