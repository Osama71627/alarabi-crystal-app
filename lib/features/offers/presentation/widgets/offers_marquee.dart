import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/models/offer.dart';

/// شريط عروض متحرك (Marquee) يعرض العناوين بحركة أفقية مستمرة
class OffersMarquee extends StatefulWidget {
  const OffersMarquee({super.key, required this.offers});

  final List<Offer> offers;

  @override
  State<OffersMarquee> createState() => _OffersMarqueeState();
}

class _OffersMarqueeState extends State<OffersMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.offers.isEmpty) return const SizedBox.shrink();
    final item = widget.offers.map((o) => o.title).join('  ✦  ');

    return Container(
      color: AppColors.primaryDark,
      height: 36,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(-(_controller.value * 200), 0),
              child: child,
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) _MarqueeText(text: item),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarqueeText extends StatelessWidget {
  const _MarqueeText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.secondaryLight,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
