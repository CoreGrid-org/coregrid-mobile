import 'package:flutter/material.dart';

/// Shared by both mock dashboard bodies for a quick action whose real
/// feature folder doesn't exist yet.
void notBuiltYet(BuildContext context, String feature) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$feature isn\'t built yet — this is a mock dashboard.'),
    ),
  );
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
  });

  final String title;
  final IconData icon;
  final List<DashboardRow> rows;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: colors.primary),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              Text(
                emptyLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
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
/// left, a status chip on the right.
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  detail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Chip(
            label: Text(status),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
