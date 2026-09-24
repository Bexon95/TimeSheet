import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/models.dart';
import '../providers/providers.dart';
import 'time_entry_form.dart';

class TimerBanner extends ConsumerStatefulWidget {
  const TimerBanner({super.key});

  @override
  ConsumerState<TimerBanner> createState() => _TimerBannerState();
}

class _TimerBannerState extends ConsumerState<TimerBanner> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(appStateProvider).activeTimer;
    if (timer == null) return const SizedBox.shrink();

    final workplace = ref.watch(appStateProvider).workplaces
        .where((w) => w.id == timer.workplaceId)
        .firstOrNull;
    if (workplace == null) return const SizedBox.shrink();

    final elapsed = DateTime.now().difference(timer.startedAt);

    return MaterialBanner(
      content: Text(
        'Timer läuft für ${workplace.name} – ${_formatElapsed(elapsed)}',
      ),
      leading: const Icon(Icons.timer),
      actions: [
        TextButton(
          onPressed: () => _stopTimer(context, workplace, timer),
          child: const Text('Stoppen'),
        ),
      ],
    );
  }

  String _formatElapsed(Duration duration) {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    final s = duration.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  Future<void> _stopTimer(
    BuildContext context,
    Workplace workplace,
    ActiveTimer timer,
  ) async {
    final end = DateTime.now();
    await showTimeEntryForm(
      context,
      workplace: workplace,
      initialDate: DateTime(
        timer.startedAt.year,
        timer.startedAt.month,
        timer.startedAt.day,
      ),
      initialStart: timer.startedAt,
      initialEnd: end,
      source: EntrySource.timer,
    );
    await ref.read(timerServiceProvider).clearTimer();
    await ref.read(appStateProvider.notifier).refreshTimer();
  }
}
