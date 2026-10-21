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

  Sport _sport = Sport.badminton;
  VenueInfo _venue = venues.first;
  int _court = 1;
  int _hour = 8;
  int _hours = 2;
  DateTime _date = DateTime.now().add(const Duration(days: 2));
  int _quota = 8;
  int _minScore = 70;
  LobbyAccess _access = LobbyAccess.open;
  final _secret = TextEditingController();
  final _inviteCode =
      'SEB-${(DateTime.now().millisecondsSinceEpoch % 9000 + 1000)}';

  DateTime get _start => DateTime(_date.year, _date.month, _date.day, _hour);

  /// Harga mengikuti tarif venue per jam: weekday atau weekend.
  int get _price => _venue.rateOn(_date) * _hours;

  String get _dayType => _venue.isWeekend(_date) ? 'Weekend' : 'Weekday';

  int get _lastHour => _venue.closeHour - _hours;

  @override
  void dispose() {
    _title.dispose();
    _secret.dispose();
    super.dispose();
  }

  void _submit() {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Judul room wajib diisi.')));
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
          venue: _venue.name,
          city: _venue.city,
          court: 'Lapangan $_court',
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
          padding: kScreenPad,
          children: [
            const RoundBackHeader(title: 'Buat room'),
            const SizedBox(height: 18),
            const Text('Isi slot,\nbagi rata.', style: T.display),
            const SizedBox(height: 8),
            const Text(
              'Pilih venue dan jam. Harga per orang dihitung otomatis '
              'dari tarif lapangan.',
              style: T.body,
            ),
            const SizedBox(height: 20),
            SportPanel(
              gradient: C.pinkPanel,
              radius: 30,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Pill(
                    'Harga per orang',
                    color: Colors.white,
                    background: Colors.black.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    rupiah(perPerson),
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.8,
                      height: 1,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${rupiah(_price)} ÷ $_quota orang'
                    '${surplus > 0 ? ' · pembulatan ${rupiah(surplus)} diteruskan ke venue' : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SurfaceCard(
              radius: 26,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Detail lapangan', style: T.h3),
                  const SizedBox(height: 14),
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
                  const _FieldLabel('Venue'),
                  const SizedBox(height: 8),
                  _DropdownBox<VenueInfo>(
                    value: _venue,
                    items: [
                      for (final v in venues)
                        DropdownMenuItem(
                          value: v,
                          child: Text(
                            v.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _venue = v;
                        if (_court > v.courts) _court = v.courts;
                        if (_hour > _lastHour) _hour = _lastHour;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_venue.city} · ${_venue.rateLabel}',
                    style: T.caption,
                  ),
                  const SizedBox(height: 18),
                  const _FieldLabel('Lapangan'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var c = 1; c <= _venue.courts; c++)
                        _SelectChip(
                          label: 'Lapangan $c',
                          selected: _court == c,
                          onTap: () => setState(() => _court = c),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const _FieldLabel('Tanggal'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      height: 54,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: C.surfaceAlt,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.event_outlined,
                            size: 19,
                            color: C.teal,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${formatLongDate(_date)} · $_dayType',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: C.ink,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.expand_more,
                            size: 20,
                            color: C.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _FieldLabel('Jam mulai · durasi $_hours jam'),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 46,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _lastHour - _venue.openHour + 1,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final h = _venue.openHour + i;
                        final active = h == _hour;
                        return GestureDetector(
                          onTap: () => setState(() => _hour = h),
                          child: Container(
                            width: 62,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: active ? C.teal : C.surfaceAlt,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: active ? C.teal : C.line,
                              ),
                            ),
                            child: Text(
                              '${h.toString().padLeft(2, '0')}:00',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: active ? Colors.white : C.ink,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final h in const [1, 2, 3])
                        _SelectChip(
                          label: '$h jam',
                          selected: _hours == h,
                          onTap: () => setState(() {
                            _hours = h;
                            if (_hour > _venue.closeHour - h) {
                              _hour = _venue.closeHour - h;
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: C.tealSoft,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.sell_outlined,
                          size: 18,
                          color: C.teal,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$_dayType · ${rupiah(_venue.rateOn(_date))}/jam '
                            '× $_hours jam = ${rupiah(_price)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.45,
                              color: C.tealDeep,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SurfaceCard(
              radius: 26,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Room & peserta', style: T.h3),
                  const SizedBox(height: 14),
                  LabeledField(
                    label: 'Judul room',
                    controller: _title,
                    textCapitalization: TextCapitalization.words,
                    prefixIcon: Icons.edit_outlined,
                  ),
                  const SizedBox(height: 16),
                  _SliderField(
                    label: 'Kuota peserta',
                    value: '$_quota orang',
                    min: 2,
                    max: 30,
                    divisions: 28,
                    current: _quota.toDouble(),
                    onChanged: (v) => setState(() => _quota = v.round()),
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
                  const SizedBox(height: 4),
                  const _FieldLabel('Akses room'),
                  const SizedBox(height: 10),
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
                        color: C.surfaceAlt,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.link, size: 18, color: C.purple),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Kode undangan', style: T.caption),
                                Text(
                                  _inviteCode,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: C.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Pill(
                            'Bagikan',
                            color: C.pinkDeep,
                            background: C.pinkSoft,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: C.amberSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_clock, size: 18, color: C.amber),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Join ditutup 6 jam sebelum mulai. Bila kuota tidak '
                      'penuh, dana yang dikunci dilepas penuh.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: C.amber,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SebarButton(
              label: 'Buat room · ${rupiah(perPerson)}/orang',
              onPressed: _submit,
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                'Sebagai host kamu ikut menanggung 1 porsi.',
                style: T.small,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null) return;
    setState(() => _date = date);
  }
}

class _DropdownBox<V> extends StatelessWidget {
  const _DropdownBox({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final V value;
  final List<DropdownMenuItem<V>> items;
  final ValueChanged<V?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: C.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: C.line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<V>(
          value: value,
          isExpanded: true,
          dropdownColor: C.surface,
          borderRadius: BorderRadius.circular(18),
          icon: const Icon(Icons.expand_more, size: 20, color: C.muted),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: C.ink,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
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
      color: selected ? C.pinkSoft : C.surfaceAlt,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? C.pink : C.line,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                access.icon,
                size: 19,
                color: selected ? C.pinkDeep : C.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      access.label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: C.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(access.hint, style: T.small),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 20,
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
    return Text(text, style: T.label);
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
      color: selected ? C.pink : C.surfaceAlt,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? C.pink : C.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: selected ? Colors.white : C.muted),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
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
            Text(label, style: T.small),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
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
