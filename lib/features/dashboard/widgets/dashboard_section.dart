import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/ui.dart';

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
    Widget placeholder(Widget child) => ClayCard(
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
