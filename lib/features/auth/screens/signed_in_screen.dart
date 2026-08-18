import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/auth/auth_controller.dart';
import '../../../shared/auth/auth_state.dart';

/// Stand-in landing screen until `features/dashboard/` exists (built last
/// per `TEAM-ALLOCATION.md` — nothing to summarise until the other features
/// do). Just proves the signed-in session and lets you sign out.
class SignedInScreen extends ConsumerWidget {
  const SignedInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    final name = state is AuthAuthenticated ? state.displayName : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CoreGrid'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Center(
        child: Text(
          name != null ? 'Signed in as $name' : 'Signed in',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
