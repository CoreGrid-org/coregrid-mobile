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

/// Shortcut tiles in a 3-column grid matching the soft rounded icon-tile design.
class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key, required this.actions});

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.lg,
        ),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: AppSpacing.lg,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.9,
          ),
          itemBuilder: (context, index) {
            return _QuickActionCard(actions[index]);
          },
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard(this.action);

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: context.colors.primaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              action.icon,
              size: 28,
              color: context.colors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            action.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.colors.onSurface,
              height: 1.2,
            ),
          ),
        ],
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
