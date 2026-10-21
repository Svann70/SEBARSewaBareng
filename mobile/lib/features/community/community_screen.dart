import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/state.dart';

/// Chat komunitas: satu kanal per topik, tanpa bubble bertumpuk.
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  int _channel = 0;

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    ref.read(chatProvider.notifier).send(chatChannels[_channel], _text.text);
    _text.clear();
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final channel = chatChannels[_channel];
    final messages = ref
        .watch(chatProvider)
        .where((m) => m.channel == channel)
        .toList()
        .reversed
        .toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const RoundBackHeader(title: 'Komunitas'),
                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.only(left: 2),
                    child: Text(
                      'Tanya jadwal, cari lawan, atau bagikan kode room.',
                      style: T.small,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: chatChannels.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => _ChannelChip(
                        label: chatChannels[i],
                        selected: i == _channel,
                        onTap: () => setState(() => _channel = i),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: messages.isEmpty
                  ? const EmptyState(
                      icon: Icons.forum_outlined,
                      title: 'Belum ada pesan',
                      message: 'Mulai percakapan di kanal ini.',
                    )
                  : ListView.separated(
                      controller: _scroll,
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      itemCount: messages.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _Message(message: messages[i]),
                    ),
            ),
            _Composer(channel: channel, controller: _text, onSend: _send),
          ],
        ),
      ),
    );
  }
}

class _ChannelChip extends StatelessWidget {
  const _ChannelChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? C.pink : C.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? C.pink : C.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : C.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.isMe;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!mine)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  message.author,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: C.muted,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: mine ? null : C.surface,
                gradient: mine
                    ? const LinearGradient(
                        colors: C.pinkPanel,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(mine ? 18 : 6),
                  bottomRight: Radius.circular(mine ? 6 : 18),
                ),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: mine ? Colors.white : C.ink,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Text(formatTime(message.at), style: T.caption),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.channel,
    required this.controller,
    required this.onSend,
  });

  final String channel;
  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      decoration: const BoxDecoration(
        color: C.bg,
        border: Border(top: BorderSide(color: C.line)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: C.ink,
                ),
                decoration: InputDecoration(
                  hintText: 'Tulis di $channel',
                  hintStyle: const TextStyle(color: C.faint, fontSize: 13),
                  filled: true,
                  fillColor: C.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: const BorderSide(color: C.pink, width: 1.4),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: C.pink,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onSend,
                child: const SizedBox(
                  width: 46,
                  height: 46,
                  child: Icon(
                    Icons.arrow_upward,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
