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
    final workplace = ref.watch(myWorkplaceProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: RefreshIndicator(
        onRefresh: () {
          ref.invalidate(myWorkplaceProvider);
          return ref.refresh(meProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppSpacing.pageInsets,
          children: [
            switch (me) {
              AsyncData(:final value) => _ProfileHero(profile: value),
              AsyncError(:final error) => Notice(
                tone: StatusTone.danger,
                title: 'Couldn\'t load your profile',
                message: errorMessageFor(error),
              ),
              _ => const SizedBox(height: 220, child: LoadingView()),
            },
            if (me.asData?.value case final profile?) ...[
              const SectionHeader('Workplace'),
              ListCard(
                children: [
                  InfoRow(
                    icon: Icons.apartment_rounded,
                    label: 'Department',
                    value:
                        workplace?.departmentName ??
                        (profile.departmentId == null ? 'None' : '…'),
                  ),
                  InfoRow(
                    icon: Icons.corporate_fare_rounded,
                    label: 'Organisation',
                    value: profile.organizationName,
                  ),
                  // Mirrors the API's DepartmentScope (SRS §4.6) so the user
                  // knows why they see what they see.
                  InfoRow(
                    icon: Icons.visibility_outlined,
                    label: 'Asset access',
                    value: profile.role == 'Staff'
                        ? 'Your department'
                        : 'Organisation-wide',
                  ),
                ],
              ),
              if (workplace != null && workplace.locations.isNotEmpty) ...[
                SectionHeader('Locations · ${workplace.locations.length}'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final l in workplace.locations)
                          Chip(
                            avatar: Icon(
                              Icons.place_outlined,
                              size: 16,
                              color: context.colors.primary,
                            ),
                            label: Text(l),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
            const SectionHeader('App & security'),
            const ListCard(
              children: [
                RecordTile(
                  icon: Icons.verified_user_outlined,
                  title: 'Signed in with ThunderID',
                  subtitle:
                      'Secure single sign-on. Your session ends when you sign '
                      'out.',
                  showChevron: false,
                ),
                RecordTile(
                  icon: Icons.desktop_windows_outlined,
                  title: 'CoreGrid web console',
                  subtitle: 'Administration, approvals and reports live there.',
                  showChevron: false,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.error,
                side: BorderSide(
                  color: context.colors.error.withValues(alpha: 0.4),
                ),
              ),
              onPressed: () => _confirmSignOut(context, ref),
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: const Text('Sign out'),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'CoreGrid Mobile · Field operations',
              textAlign: TextAlign.center,
              style: context.mutedSmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Brand banner with an overlapping avatar, then name, email and role.
class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile});

  final MeProfile profile;

  static const _banner = 76.0;
  static const _avatar = 44.0;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          SizedBox(
            height: _banner + _avatar,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Container(
                  height: _banner,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [CoreGridBrand.greenDeep, Color(0xFF0B4A3A)],
                    ),
                  ),
                ),
                Positioned(
                  top: _banner - _avatar,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: context.theme.cardTheme.color,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: _avatar,
                      backgroundColor: context.colors.primaryContainer,
                      child: Text(
                        profile.initials,
                        style: context.text.headlineSmall?.copyWith(
                          color: context.colors.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: Column(
              children: [
                Text(
                  profile.fullName,
                  textAlign: TextAlign.center,
                  style: context.text.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  profile.email,
                  textAlign: TextAlign.center,
                  style: context.mutedBody,
                ),
                const SizedBox(height: AppSpacing.md),
                StatusPill(profile.roleName, tone: StatusTone.info),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
