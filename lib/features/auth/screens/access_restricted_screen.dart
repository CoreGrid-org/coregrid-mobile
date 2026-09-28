import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/auth/auth_controller.dart';
import '../../../shared/widgets/ui.dart';

/// Shown when the signed-in account's role is not supported by this app.
class AccessRestrictedScreen extends ConsumerWidget {
  const AccessRestrictedScreen({super.key, required this.role});

  final String role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: MessageView(
          icon: Icons.desktop_windows_outlined,
          tone: StatusTone.info,
          title: 'This account isn\'t supported on the mobile app',
          message:
              '${roleLabel(role)} accounts use the CoreGrid web console instead.',
          action: FilledButton(
            onPressed: () {
              ref.read(authControllerProvider.notifier).signOut();
              context.go('/sign-in');
            },
            child: const Text('Back to Sign In'),
          ),
        ),
      ),
    );
  }
}
