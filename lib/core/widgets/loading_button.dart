import 'package:flutter/material.dart';

/// زر تحميل دائري داخل الأزرار
class LoadingButton extends StatelessWidget {
  const LoadingButton({
    super.key,
    this.isLoading = false,
    this.label,
    this.onPressed,
    this.buttonStyle,
    this.child,
  });

  final bool isLoading;
  final String? label;
  final VoidCallback? onPressed;
  final ButtonStyle? buttonStyle;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return ElevatedButton(
        onPressed: null,
        style: buttonStyle,
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white,
          ),
        ),
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: buttonStyle,
      child: child ?? Text(label ?? ''),
    );
  }
}
