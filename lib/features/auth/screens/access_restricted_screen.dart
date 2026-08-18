import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/auth/auth_controller.dart';

/// Shown when ThunderID accepts sign-in but the account's role isn't served
/// by this app — Auditor and Administrator are web-console-only (SRS §3.4,
/// FR-059/067/069 scope change). Mirrors the React frontend's own
/// `/access-restricted` route (`CoreGrid/doc/setup/ThunderID.md`).
class AccessRestrictedScreen extends ConsumerWidget {
  const AccessRestrictedScreen({super.key, required this.role});

  final String role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.block_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 24),
              Text(
                'This account isn\'t supported on the mobile app',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${roleLabel(role)} accounts use the CoreGrid web console instead.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () {
                  ref.read(authControllerProvider.notifier).signOut();
                  context.go('/sign-in');
                },
                child: const Text('Back to Sign In'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
