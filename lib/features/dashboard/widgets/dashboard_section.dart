import 'package:flutter/material.dart';

/// Shared by both dashboard bodies for a quick action whose real feature
/// folder doesn't exist yet.
void notBuiltYet(BuildContext context, String feature) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$feature isn\'t built yet — this is a mock dashboard.'),
    ),
  );
}

/// Maps a status label to a semantic color — Material 3 has no built-in
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

/// One quick-action tile — icon-in-a-circle over a label, used for the row
/// of shortcuts atop each role's dashboard. A nicer, more scannable grouping
/// than a row of plain buttons; [primary] tints the tile with [accent]
/// (the role's [RoleAccent]) to mark the one primary action (e.g. "Scan
/// Asset"/"Report Fault") — everything else stays neutral.
class QuickActionTile extends StatelessWidget {
  const QuickActionTile({
    super.key,
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tint = accent ?? colors.primary;
    final background = primary ? tint : colors.surfaceContainerHigh;
    final foreground = primary ? _onColor(tint) : colors.onSurface;

    return SizedBox(
      width: 84,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: foreground, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  /// A readable foreground for an arbitrary brand accent used as a fill —
  /// every current [RoleAccent] is dark enough for white text/icons, but
  /// this keeps the tile correct if a lighter accent is added later.
  Color _onColor(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? Colors.white
      : Colors.black;
}

/// One labelled card of rows on a dashboard — shared by
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

  /// Tints the header icon's circle — defaults to the theme's primary when
  /// omitted, so a section can pick up a role's accent color instead.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tint = accent ?? colors.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: tint.withValues(alpha: 0.14),
                  child: Icon(icon, size: 18, color: tint),
                ),
                const SizedBox(width: 10),
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
                padding: const EdgeInsets.only(top: 8, left: 42),
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

/// One row within a [DashboardSection] — an asset code / description on the
/// left, a status chip on the right, semantically colored by [statusColor].
class DashboardRow extends StatelessWidget {
  const DashboardRow({
    super.key,
    required this.label,
    required this.detail,
    required this.status,
  });

  final String label;
  final String detail;
  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tint = statusColor(context, status);

    return Padding(
      padding: const EdgeInsets.only(top: 10, left: 42),
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
  }
}
