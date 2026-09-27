import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/ui.dart';

/// Config for one [QuickActionsGrid] entry.
class QuickAction {
  const QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.caption,
  });

  final IconData icon;
  final String label;
  final String? caption;
  final VoidCallback onTap;
}

/// Shortcut cards in a two-column grid; an odd last card spans the row.
class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key, required this.actions});

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < actions.length; i += 2) {
      final pair = actions.skip(i).take(2).toList();
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _QuickActionCard(pair[0])),
              if (pair.length == 2) ...[
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _QuickActionCard(pair[1])),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          rows[i],
        ],
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard(this.action);

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md + 2),
          child: Row(
            children: [
              IconTile(action.icon, size: 40),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      action.label,
                      style: context.text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (action.caption != null)
                      Text(
                        action.caption!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.mutedSmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A titled preview of a longer list on the dashboard, with "See all" and
/// the shared loading / empty / error handling for [AsyncValue] data.
class DashboardPreview<T> extends StatelessWidget {
  const DashboardPreview({
    super.key,
    required this.title,
    required this.data,
    required this.itemBuilder,
    required this.emptyLabel,
    this.onSeeAll,
    this.maxItems = 3,
  });

  final String title;
  final AsyncValue<List<T>> data;
  final Widget Function(T item) itemBuilder;
  final String emptyLabel;
  final VoidCallback? onSeeAll;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final muted = context.mutedBody;
    Widget placeholder(Widget child) => Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: child,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title,
          actionLabel: onSeeAll == null ? null : 'See all',
          onAction: onSeeAll,
          padding: const EdgeInsets.only(
            top: AppSpacing.xl,
            bottom: AppSpacing.xs,
          ),
        ),
        switch (data) {
          AsyncData(:final value) when value.isEmpty => placeholder(
            Text(emptyLabel, style: muted),
          ),
          AsyncData(:final value) => ListCard(
            children: [
              for (final item in value.take(maxItems)) itemBuilder(item),
            ],
          ),
          AsyncError(:final error) => Notice(
            tone: StatusTone.danger,
            message: errorMessageFor(error),
          ),
          _ => placeholder(const LinearProgressIndicator()),
        },
      ],
    );
  }
}
