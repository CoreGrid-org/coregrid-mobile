import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/auth/auth_controller.dart';
import '../../../shared/auth/me_provider.dart';
import '../../../shared/widgets/ui.dart';

/// The Account tab: who is signed in (from `GET /api/me`), and sign-out.
/// Sign-out revokes the refresh token and clears local state (FR-008,
/// SRS §4.8) — the shell then routes back to sign-in.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You\'ll need to sign in with ThunderID again to use CoreGrid.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final workplace = ref.watch(myWorkplaceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(meProvider.future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppSpacing.pageInsets,
          children: [
            switch (me) {
              AsyncData(:final value) => _ProfileCard(
                profile: value,
                department: workplace.asData?.value?.departmentName,
              ),
              AsyncError(:final error) => Notice(
                tone: StatusTone.danger,
                title: 'Couldn\'t load your profile',
                message: errorMessageFor(error),
              ),
              _ => const SizedBox(height: 140, child: LoadingView()),
            },
            ...switch (workplace) {
              AsyncData(value: final w?) when w.locations.isNotEmpty => [
                SectionHeader('Your locations · ${w.locations.length}'),
                ListCard(
                  children: [
                    for (final l in w.locations)
                      RecordTile(
                        icon: Icons.place_outlined,
                        title: l,
                        showChevron: false,
                      ),
                  ],
                ),
              ],
              AsyncError(:final error) => [
                const SizedBox(height: AppSpacing.md),
                Notice(
                  tone: StatusTone.danger,
                  message: errorMessageFor(error),
                ),
              ],
              _ => const <Widget>[],
            },
            const SectionHeader('About'),
            const ListCard(
              children: [
                InfoRow(
                  icon: Icons.phone_android_outlined,
                  label: 'App',
                  value: 'CoreGrid Mobile',
                ),
                InfoRow(
                  icon: Icons.lock_outline,
                  label: 'Sign-in',
                  value: 'ThunderID',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Administration, approvals and reports are in the CoreGrid web '
              'console.',
              style: context.mutedSmall,
            ),
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.error,
              ),
              onPressed: () => _confirmSignOut(context, ref),
              icon: const Icon(Icons.logout, size: 20),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.department});

  final MeProfile profile;
  final String? department;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: EntityHeader(
              large: true,
              title: profile.fullName,
              subtitle: profile.email,
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: context.colors.primary,
                child: Text(
                  profile.initials,
                  style: context.text.titleMedium?.copyWith(
                    color: context.colors.onPrimary,
                  ),
                ),
              ),
            ),
          ),
          const Divider(),
          InfoRow(
            icon: Icons.badge_outlined,
            label: 'Role',
            value: profile.roleName,
          ),
          InfoRow(
            icon: Icons.apartment_outlined,
            label: 'Department',
            value:
                department ??
                (profile.departmentId == null ? 'Organisation-wide' : '…'),
          ),
        ],
      ),
    );
  }
}
