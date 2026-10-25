import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/state.dart';

/// Ubah data akun (nama, nomor HP) dan password. Foto profil tidak didukung.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final String _originalName;
  late final String _originalPhone;
  late final TextEditingController _name;
  late final TextEditingController _phone;
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  String? _pwError;
  bool _busy = false;
  bool _busyPw = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(sessionProvider);
    _originalName = user?.fullName ?? '';
    _originalPhone = user?.phone ?? '';
    _name = TextEditingController(text: _originalName);
    _phone = TextEditingController(text: _originalPhone);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _phoneChanged => _phone.text.trim() != _originalPhone;

  Future<void> _saveProfile() async {
    if (_busy) return;
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    if (name.length < 3) {
      setState(() => _error = 'Nama minimal 3 karakter.');
      return;
    }
    if (phone.isNotEmpty && !RegExp(r'^\+?[0-9]{8,15}$').hasMatch(phone)) {
      setState(() => _error = 'Format nomor telepon belum benar.');
      return;
    }
    if (name == _originalName && !_phoneChanged) {
      setState(() => _error = 'Belum ada perubahan yang dilakukan.');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    final error = await ref
        .read(authProvider.notifier)
        .updateProfile(
          fullName: name,
          phone: phone.isNotEmpty ? phone : null,
          clearPhone: phone.isEmpty,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil berhasil diperbarui.')),
    );
    context.pop();
  }

  Future<void> _savePassword() async {
    if (_busyPw) return;
    if (_current.text.isEmpty) {
      setState(() => _pwError = 'Password saat ini wajib diisi.');
      return;
    }
    if (_next.text.length < 8) {
      setState(() => _pwError = 'Password baru minimal 8 karakter.');
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _pwError = 'Konfirmasi password tidak sama.');
      return;
    }
    setState(() {
      _pwError = null;
      _busyPw = true;
    });
    final error = await ref
        .read(authProvider.notifier)
        .changePassword(current: _current.text, next: _next.text);
    if (!mounted) return;
    setState(() => _busyPw = false);
    if (error != null) {
      setState(() => _pwError = error);
      return;
    }
    // Server mencabut semua sesi setelah password berubah — wajib masuk ulang.
    await ref.read(authProvider.notifier).signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password diubah. Silakan masuk ulang.')),
    );
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            const RoundBackHeader(title: 'Edit profil'),
            const SizedBox(height: 28),
            Text('Data akun', style: T.h2),
            const SizedBox(height: 14),
            // Email tidak boleh diubah lewat app ini.
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email', style: T.label),
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(Icons.mail_outline, size: 19, color: C.muted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        user?.email ?? '-',
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: C.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
              label: 'Nomor HP (opsional)',
              controller: _phone,
              hint: 'Contoh: 0812345678',
              keyboard: TextInputType.phone,
              prefixIcon: Icons.phone_outlined,
            ),
            _ErrorRow(message: _error),
            const SizedBox(height: 20),
            SebarButton(
              label: _busy ? 'Menyimpan…' : 'Simpan perubahan',
              onPressed: _busy ? null : _saveProfile,
            ),
            const SizedBox(height: 32),
            Text('Ubah password', style: T.h2),
            const SizedBox(height: 14),
            LabeledField(
              label: 'Password saat ini',
              controller: _current,
              hint: 'Masuk dengan password lama',
              obscure: true,
              prefixIcon: Icons.lock_outline,
            ),
            const SizedBox(height: 14),
            LabeledField(
              label: 'Password baru',
              controller: _next,
              hint: 'Minimal 8 karakter',
              obscure: true,
              prefixIcon: Icons.lock_reset_outlined,
            ),
            const SizedBox(height: 14),
            LabeledField(
              label: 'Ulangi password baru',
              controller: _confirm,
              hint: 'Ketik ulang password baru',
              obscure: true,
              prefixIcon: Icons.lock_reset_outlined,
            ),
            _ErrorRow(message: _pwError),
            const SizedBox(height: 20),
            GhostButton(
              label: _busyPw ? 'Mengubah…' : 'Ubah password',
              icon: Icons.key_outlined,
              onPressed: _busyPw ? null : _savePassword,
            ),
            const SizedBox(height: 14),
            const Text(
              'Setelah password berubah, semua perangkat wajib masuk ulang.',
              style: T.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 16, color: C.danger),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              message!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: C.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
