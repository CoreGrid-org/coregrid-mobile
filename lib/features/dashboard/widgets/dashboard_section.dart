import 'package:flutter/material.dart';

/// Shared by both dashboard bodies for a quick action whose real feature
/// folder doesn't exist yet.
void notBuiltYet(BuildContext context, String feature) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$feature isn\'t built yet, this is a mock dashboard.'),
    ),
  );
}

/// Maps a status label to a semantic color. Material 3 has no built-in
/// success/warning roles, so this is a small, deliberately conservative
/// palette shared by every status chip on the dashboard rather than each
/// section picking its own ad hoc colors.
Color statusColor(BuildContext context, String status) {
  final colors = Theme.of(context).colorScheme;
  return switch (status.toLowerCase()) {
    'completed' || 'resolved' || 'active' => const Color(0xFF2E7D32),
    'in progress' || 'in transit' || 'pending' => const Color(0xFFB8860B),
    'overdue' || 'failed' => colors.error,
    _ => colors.onSurfaceVariant,
  };
}

/// Config for one [QuickActionsGrid] entry.
class QuickAction {
  const QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? accent;
  final bool primary;
}

/// The row of shortcuts atop each role's dashboard, as a fixed 4-column
/// grid rather than a `Wrap` so it stays evenly aligned regardless of how
/// many actions a role has, instead of leaving a ragged half-filled last
/// row. Icon language matches `OnboardingScreen`'s rounded squares, not a
/// circle, so the dashboard reads as the same design system as the intro.
class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key, required this.actions});

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 8,
      childAspectRatio: 0.78,
      children: [for (final action in actions) _QuickActionTile(action)],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile(this.action);

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tint = action.accent ?? colors.primary;
    final background = action.primary ? tint : tint.withValues(alpha: 0.10);
    final foreground = action.primary ? _onColor(tint) : tint;

    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(action.icon, color: foreground, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            action.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  /// A readable foreground for an arbitrary brand accent used as a fill.
  /// Every current `RoleAccent` is dark enough for white text/icons, but
  /// this keeps the tile correct if a lighter accent is added later.
  Color _onColor(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? Colors.white
      : Colors.black;
}

/// One labelled card of rows on a dashboard, shared by
/// [OfficerDashboardScreen] and [StaffDashboardScreen] so each only states
/// its own section titles and rows, not the card chrome.
class DashboardSection extends StatelessWidget {
  const DashboardSection({
    super.key,
    required this.title,
    required this.icon,
    required this.rows,
    this.emptyLabel = 'Nothing here right now',
    this.accent,
  });

  final String title;
  final IconData icon;
  final List<DashboardRow> rows;
  final String emptyLabel;

  /// Tints the header icon tile, defaults to the theme's primary when
  /// omitted, so a section can pick up a role's accent color instead.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tint = accent ?? colors.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: tint),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10, left: 46),
                child: Text(
                  emptyLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final row in rows) row,
          ],
        ),
      ),
    );
  }
}

/// One row within a [DashboardSection]: an asset code / description on the
/// left, a status chip on the right, semantically colored by [statusColor].
class DashboardRow extends StatelessWidget {
  const DashboardRow({
    super.key,
    required this.label,
    required this.detail,
    required this.status,
    this.onTap,
  });

  final String label;
  final String detail;
  final String status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tint = statusColor(context, status);

    final Widget child = Padding(
      padding: const EdgeInsets.only(top: 12, left: 46),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  detail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: tint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: child,
      );
    }
    return child;
  }
}
