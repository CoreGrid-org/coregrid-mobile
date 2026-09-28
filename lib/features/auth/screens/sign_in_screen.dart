import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/auth/auth_controller.dart';
import '../../../shared/auth/auth_state.dart';
import '../../../shared/auth/password_recovery.dart';
import '../../../shared/widgets/ui.dart';

/// Sign-in screen — authenticates via OAuth2 PKCE.
class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next is AuthAuthenticated) {
        context.go('/home');
      } else if (next is AuthRoleNotSupported) {
        context.go('/access-restricted', extra: next.role);
      } else if (next is AuthError) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.message)));
      }
    });

    final state = ref.watch(authControllerProvider);
    final isAuthenticating = state is AuthAuthenticating;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = context.mutedBody;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 3),
              Center(
                child: Image.asset(
                  isDark
                      ? 'assets/branding/w-coregrid.webp'
                      : 'assets/branding/coregrid.webp',
                  width: 120,
                  height: 120,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'CoreGrid',
                textAlign: TextAlign.center,
                style: context.text.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Asset field operations',
                textAlign: TextAlign.center,
                style: muted,
              ),
              const Spacer(flex: 4),
              SubmitButton(
                label: 'Sign In',
                busyLabel: 'Signing In…',
                icon: Icons.login_rounded,
                busy: isAuthenticating,
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).signIn(),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: isAuthenticating
                    ? null
                    : () => openPasswordRecovery(context),
                child: const Text('Forgot password?'),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 14,
                    color: context.colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      'Secure sign-in with ThunderID opens in your browser',
                      textAlign: TextAlign.center,
                      style: context.mutedSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
