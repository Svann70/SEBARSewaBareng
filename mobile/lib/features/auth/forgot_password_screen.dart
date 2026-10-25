import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/state.dart';
import 'login_screen.dart';
/// Layar untuk meminta tautan reset password melalui email.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}
class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }
  Future<void> _submit() async {
    if (_busy) return;
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Email wajib diisi.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Format email belum benar.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await ref.read(authProvider.notifier).forgotPassword(email);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _sent = true);
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
            if (!_sent) ...[
              // ── FORM INPUT EMAIL ──────────────────────────────────────────
              const Text('Lupa Password', style: T.display),
              const SizedBox(height: 8),
              const Text(
                'Masukkan email akunmu. Kami akan mengirimkan tautan untuk mengatur ulang password.',
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
                label: _busy ? 'Mengirim…' : 'Kirim Tautan Reset',
                onPressed: _busy ? null : _submit,
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Ingat password?', style: T.small),
                  TextButton(
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/login'),
                    child: const Text('Masuk'),
                  ),
                ],
              ),
            ] else ...[
              // ── STATE SETELAH BERHASIL DIKIRIM ────────────────────────────
              const Text('Periksa Email Kamu', style: T.display),
              const SizedBox(height: 8),
              Text(
                'Kami telah mengirimkan tautan reset password ke ${_email.text.trim()}. Silakan cek kotak masuk atau folder spam kamu.',
                style: T.body,
              ),
              const SizedBox(height: 24),
              SurfaceCard(
                radius: 18,
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.mark_email_read_outlined,
                      size: 24,
                      color: C.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tidak menerima email? Pastikan email sudah benar atau periksa folder spam.',
                        style: T.small,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SebarButton(
                label: 'Kembali ke Masuk',
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/login'),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _busy ? null : _submit,
                  child: const Text('Kirim ulang tautan'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}