import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/state.dart';

class CreateLobbyScreen extends ConsumerStatefulWidget {
  const CreateLobbyScreen({super.key});

  @override
  ConsumerState<CreateLobbyScreen> createState() => _CreateLobbyScreenState();
}

class _CreateLobbyScreenState extends ConsumerState<CreateLobbyScreen> {
  final _title = TextEditingController(text: 'Badminton Sabtu Pagi');
  final _venue = TextEditingController(text: 'GOR C-Tra Arena');
  final _court = TextEditingController(text: 'Lapangan 3');

  Sport _sport = Sport.badminton;
  String _city = 'Bandung';
  int _quota = 8;
  int _price = 400000;
  int _minScore = 70;
  DateTime _start = DateTime.now().add(const Duration(days: 2, hours: 2));
  LobbyAccess _access = LobbyAccess.open;
  final _secret = TextEditingController();
  final _inviteCode =
      'SEB-${(DateTime.now().millisecondsSinceEpoch % 9000 + 1000)}';

  @override
  void dispose() {
    _title.dispose();
    _venue.dispose();
    _court.dispose();
    _secret.dispose();
    super.dispose();
  }

  void _submit() {
    if (_title.text.trim().isEmpty || _venue.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul dan venue wajib diisi.')),
      );
      return;
    }
    if (_access == LobbyAccess.password && _secret.text.trim().length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sandi room minimal 4 karakter.')),
      );
      return;
    }
    ref
        .read(lobbiesProvider.notifier)
        .create(
          title: _title.text.trim(),
          sport: _sport,
          venue: _venue.text.trim(),
          city: _city,
          court: _court.text.trim().isEmpty ? 'Lapangan 1' : _court.text.trim(),
          start: _start,
          priceTotal: _price,
          quota: _quota,
          minReliability: _minScore,
          access: _access,
          secret: switch (_access) {
            LobbyAccess.open => null,
            LobbyAccess.link => _inviteCode,
            LobbyAccess.password => _secret.text.trim(),
          },
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _access == LobbyAccess.link
              ? 'Room dibuat. Bagikan kode $_inviteCode.'
              : '${rupiah(pricePerPerson(_price, _quota))} dikunci sebagai host.',
        ),
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final perPerson = pricePerPerson(_price, _quota);
    final surplus = roundingSurplus(_price, _quota);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            const RoundBackHeader(title: 'Buat room'),
            const SizedBox(height: 16),
            const Text('Isi slot,\nbagi rata.', style: T.display),
            const SizedBox(height: 6),
            const Text(
              'Harga per orang dihitung database, bukan perkiraan klien.',
              style: T.body,
            ),
            const SizedBox(height: 18),
            SportPanel(
              gradient: [Color(0xFF9B8CFF), Color(0xFF6A5AE0)],
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Pill('Harga per orang', background: Colors.white24),
                  const SizedBox(height: 10),
                  Text(
                    rupiah(perPerson),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.4,
                      height: 1,
                      color: C.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${rupiah(_price)} ÷ $_quota orang'
                    '${surplus > 0 ? ' · surplus ${rupiah(surplus)} ke venue' : ''}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _FieldLabel('Olahraga'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in Sport.values)
                  _SelectChip(
                    label: s.label,
                    icon: s.icon,
                    selected: _sport == s,
                    onTap: () => setState(() => _sport = s),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const _FieldLabel('Akses room'),
            const SizedBox(height: 8),
            for (final a in LobbyAccess.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AccessOption(
                  access: a,
                  selected: _access == a,
                  onTap: () => setState(() => _access = a),
                ),
              ),
            if (_access == LobbyAccess.password) ...[
              const SizedBox(height: 4),
              LabeledField(
                label: 'Sandi room',
                controller: _secret,
                hint: 'Minimal 4 karakter',
                obscure: true,
                prefixIcon: Icons.lock_outline,
              ),
            ],
            if (_access == LobbyAccess.link)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: C.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 17, color: C.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kode undangan',
                            style: TextStyle(fontSize: 10.5, color: C.muted),
                          ),
                          Text(
                            _inviteCode,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: C.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      'Bagikan',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: C.pink,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            LabeledField(label: 'Judul room', controller: _title),
            const SizedBox(height: 12),
            LabeledField(label: 'Venue', controller: _venue),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: LabeledField(label: 'Lapangan', controller: _court),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('Kota'),
                      const SizedBox(height: 6),
                      Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: C.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: C.line),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _city,
                            isExpanded: true,
                            dropdownColor: C.surface,
                            borderRadius: BorderRadius.circular(14),
                            icon: const Icon(
                              Icons.expand_more,
                              size: 18,
                              color: C.muted,
                            ),
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: C.ink,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Bandung',
                                child: Text('Bandung'),
                              ),
                              DropdownMenuItem(
                                value: 'Jakarta',
                                child: Text('Jakarta'),
                              ),
                              DropdownMenuItem(
                                value: 'Surabaya',
                                child: Text('Surabaya'),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _city = v ?? 'Bandung'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _FieldLabel('Mulai'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickStart,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: C.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: C.line),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_outlined, size: 17, color: C.green),
                    const SizedBox(width: 10),
                    Text(
                      '${formatDate(_start)} · ${formatTime(_start)}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: C.ink,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: C.muted,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            _SliderField(
              label: 'Kuota peserta',
              value: '$_quota orang',
              min: 2,
              max: 30,
              current: _quota.toDouble(),
              onChanged: (v) => setState(() => _quota = v.round()),
            ),
            _SliderField(
              label: 'Harga lapangan',
              value: rupiah(_price),
              min: 50000,
              max: 1500000,
              divisions: 29,
              current: _price.toDouble(),
              onChanged: (v) =>
                  setState(() => _price = (v / 50000).round() * 50000),
            ),
            _SliderField(
              label: 'Skor minimum',
              value: '$_minScore',
              min: 0,
              max: 100,
              divisions: 20,
              current: _minScore.toDouble(),
              onChanged: (v) => setState(() => _minScore = v.round()),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: C.butter,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock, size: 16, color: C.amber),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'Join ditutup 6 jam sebelum mulai. Kuota tidak penuh = '
                      'hold dilepas 100%.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: C.amber,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SebarButton(
              label: 'Buat room · ${rupiah(perPerson)} dikunci',
              onPressed: _submit,
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Sebagai host kamu ikut menanggung 1 porsi.',
                style: T.small,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStart() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _start.hour, minute: 0),
    );
    if (!mounted) return;
    setState(() {
      _start = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _start.hour,
        0,
      );
    });
  }
}

class _AccessOption extends StatelessWidget {
  const _AccessOption({
    required this.access,
    required this.selected,
    required this.onTap,
  });

  final LobbyAccess access;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: C.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? C.pink : C.line),
          ),
          child: Row(
            children: [
              Icon(
                access.icon,
                size: 17,
                color: selected ? C.pink : C.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      access.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: C.ink,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(access.hint, style: T.small),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 18,
                color: selected ? C.pink : C.faint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: C.muted,
      ),
    );
  }
}

class _SelectChip extends StatelessWidget {
  const _SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? C.pink : C.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? C.pink : C.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: selected ? Colors.white : C.muted),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : C.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliderField extends StatelessWidget {
  const _SliderField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.current,
    required this.onChanged,
    this.divisions,
  });

  final String label;
  final String value;
  final double min;
  final double max;
  final double current;
  final ValueChanged<double> onChanged;
  final int? divisions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: C.muted),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: C.ink,
              ),
            ),
          ],
        ),
        Slider(
          value: current.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
