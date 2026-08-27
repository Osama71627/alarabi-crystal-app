import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/email_verification_service.dart';

/// شاشة التحقق من البريد الإلكتروني بكود مكوّن من 6 أرقام
class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _codeController = TextEditingController();
  bool _sending = false;
  bool _verifying = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendCode());
  }

  @override
  void dispose() {
    _codeController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _cooldown -= 1);
      if (_cooldown <= 0) timer.cancel();
    });
  }

  Future<void> _sendCode() async {
    if (_sending || _cooldown > 0) return;
    setState(() => _sending = true);
    try {
      final alreadyVerified = await EmailVerificationService.instance.sendCode();
      if (alreadyVerified) {
        await AuthService.instance.refreshEmailVerified();
        if (!mounted) return;
        context.go(AppRoutes.home);
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.emailVerificationSent)),
      );
      _startCooldown();
    } on EmailVerificationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.errorGeneric)),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) return;
    setState(() => _verifying = true);
    try {
      await EmailVerificationService.instance.verifyCode(code);
      await AuthService.instance.refreshEmailVerified();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.codeVerifiedSuccess)),
      );
      context.go(AppRoutes.home);
    } on EmailVerificationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.errorGeneric)),
      );
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _logout() async {
    await AuthService.instance.signOut();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthService.instance.currentUser?.email ?? '';
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_read_outlined,
                    size: 40,
                    color: AppColors.secondary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppStrings.verifyEmailTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.verifyEmailSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 32),

              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 12,
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '000000',
                ),
              ),
              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: (_verifying || _codeController.text.trim().length != 6)
                    ? null
                    : _verify,
                child: _verifying
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(AppStrings.verifyCode),
              ),
              const SizedBox(height: 16),

              Center(
                child: TextButton(
                  onPressed: (_sending || _cooldown > 0) ? null : _sendCode,
                  child: Text(
                    _sending
                        ? AppStrings.sendingCode
                        : _cooldown > 0
                            ? '${AppStrings.resendCodeIn} ${_cooldown}s'
                            : AppStrings.resendCode,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Center(
                child: TextButton(
                  onPressed: _logout,
                  child: Text(
                    AppStrings.wrongEmailLogout,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
