import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../l10n/app_strings.dart';

/// عدّاد تنازلي لعروض الفلاش
class FlashCountdown extends StatefulWidget {
  const FlashCountdown({super.key, required this.endTime, this.compact = false});

  final DateTime endTime;
  final bool compact;

  @override
  State<FlashCountdown> createState() => _FlashCountdownState();
}

class _FlashCountdownState extends State<FlashCountdown> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _remaining = widget.endTime.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining = widget.endTime.difference(DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _pad(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final expired = _remaining.isNegative;
    if (expired) {
      return Text(
        AppStrings.offerEnded,
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontWeight: FontWeight.w700,
          fontSize: widget.compact ? 12 : 14,
        ),
      );
    }

    final d = _remaining.inDays;
    final h = _remaining.inHours % 24;
    final m = _remaining.inMinutes % 60;
    final s = _remaining.inSeconds % 60;

    if (widget.compact) {
      final time = d > 0
          ? '$d ${AppStrings.days} $h ${AppStrings.hours}'
          : h > 0
              ? '$h ${AppStrings.hours} $m ${AppStrings.minutes}'
              : '$m ${AppStrings.minutes} $s ${AppStrings.seconds}';
      return Text(
        '${AppStrings.offerEndsIn} $time',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      );
    }

    final units = [d, h, m, s];
    final labels = [
      AppStrings.days,
      AppStrings.hours,
      AppStrings.minutes,
      AppStrings.seconds,
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < units.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          _UnitBox(value: _pad(units[i]), label: labels[i]),
        ],
      ],
    );
  }
}

class _UnitBox extends StatelessWidget {
  const _UnitBox({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
