import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/state.dart';

/// Satu pintu masuk untuk pemain dan mitra venue — tidak ada pemilih peran,
/// peran dibaca dari akun ([roleForEmail]) supaya tidak membingungkan.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController(text: 'raka@sebar.app');
  final _password = TextEditingController(text: 'password123');

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_email.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Email belum diisi.')));
      return;
    }
    if (_password.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password minimal 8 karakter.')),
      );
      return;
    }
    final role = roleForEmail(_email.text);
    ref.read(authProvider.notifier).login(role);
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
            const SizedBox(height: 34),
            const Text('Masuk', style: T.display),
            const SizedBox(height: 8),
            const Text(
              'Pakai email dan password akunmu untuk lanjut.',
              style: T.body,
            ),
            const SizedBox(height: 24),
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
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tautan reset dikirim ke emailmu.'),
                  ),
                ),
                child: const Text('Lupa password?'),
              ),
            ),
            const SizedBox(height: 10),
            SebarButton(label: 'Masuk', onPressed: _submit),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Belum punya akun?', style: T.small),
                TextButton(
                  onPressed: () => context.push('/register'),
                  child: const Text('Daftar'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const _RoleNote(),
          ],
        ),
      ),
    );
  }
}

class _RoleNote extends StatelessWidget {
  const _RoleNote();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.storefront_outlined, size: 18, color: C.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Kelola lapangan? Masuk dengan akun mitra (email berakhiran '
              '@venue.sebar.app), otomatis dibawa ke dashboard venue.',
              style: T.small,
            ),
          ),
        ],
      ),
    );
  }
}

/// Logo SEBAR yang dipakai di layar masuk dan daftar.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: C.primaryPanel,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.sports_tennis, size: 21, color: Colors.white),
        ),
        const SizedBox(width: 11),
        const Text(
          'SEBAR',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: C.ink,
          ),
        ),
      ],
    );
  }
}
