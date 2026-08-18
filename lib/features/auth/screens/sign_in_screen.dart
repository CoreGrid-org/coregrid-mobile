import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/auth/auth_controller.dart';
import '../../../shared/auth/auth_state.dart';

/// Splash / sign-in screen — SRS §4.1 (FR-001, FR-008, SEC-ID-06).
///
/// "Sign In" launches the ThunderID Authorization Code + PKCE flow via
/// Chrome Custom Tabs (RFC 8252 external user agent — never an embedded
/// WebView), not a native username/password form: ThunderID itself doesn't
/// support a password grant, and collecting credentials in-app would defeat
/// SSO/MFA and train users to enter passwords into arbitrary apps.
class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next is AuthAuthenticated) {
        context.go('/home');
      } else if (next is AuthError) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.message)));
      }
    });

    final state = ref.watch(authControllerProvider);
    final isAuthenticating = state is AuthAuthenticating;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 3),
              Image.asset(
                isDark
                    ? 'assets/branding/w-coregrid.webp'
                    : 'assets/branding/coregrid.webp',
                width: 140,
                height: 140,
              ),
              const SizedBox(height: 24),
              Text(
                'CoreGrid',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Field Operations',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
              ),
              const Spacer(flex: 4),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: isAuthenticating
                      ? null
                      : () => ref.read(authControllerProvider.notifier).signIn(),
                  icon: isAuthenticating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(isAuthenticating ? 'Signing In…' : 'Sign In'),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Sign-in opens ThunderID in your browser',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
