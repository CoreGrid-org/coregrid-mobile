import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'status_pill.dart';

/// A simple icon — sized and optionally tinted by [tone] or [color].
/// Replaces the former tinted rounded-square badge with a plain icon.
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.tone, this.color, this.size = 40});

  final IconData icon;

  /// Semantic tint; wins over [color]. Neither → brand primary.
  final StatusTone? tone;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final fg = color ?? scheme.primary;
    return Icon(icon, color: fg, size: size * 0.55);
  }
}


/// Group title above a block of content, with an optional trailing action
/// ("See all").
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.actionLabel,
    this.onAction,
    this.padding = AppSpacing.sectionGap,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: context.text.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                foregroundColor: context.colors.onSurface,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// A tappable row: icon tile, title, subtitle, and a trailing widget
/// (typically a [StatusPill]) plus chevron. Used for every list of records
/// so tasks, faults, workflows and campaigns look like one family.
class RecordTile extends StatelessWidget {
  const RecordTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconTone,
    this.trailing,
    this.onTap,
    this.showChevron = true,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final StatusTone? iconTone;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 2,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              IconTile(icon!, tone: iconTone),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.mutedSmall,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
            if (onTap != null && showChevron) ...[
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: context.colors.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A card holding a vertical list of children separated by hairlines —
/// the standard container for [RecordTile]s and [InfoRow]s.
class ListCard extends StatelessWidget {
  const ListCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: AppSpacing.lg),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Label / value pair for read-only detail screens.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: context.colors.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(flex: 2, child: Text(label, style: context.mutedBody)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: context.text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A simple inline hint — icon + message text, no background.
class Notice extends StatelessWidget {
  const Notice({
    super.key,
    required this.message,
    this.title,
    this.tone = StatusTone.info,
    this.icon,
  });

  final String message;
  final String? title;
  final StatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final muted = context.colors.onSurfaceVariant;
    final resolvedIcon =
        icon ??
        switch (tone) {
          StatusTone.success => Icons.check_circle_outline,
          StatusTone.warning => Icons.warning_amber_rounded,
          StatusTone.danger => Icons.error_outline,
          _ => Icons.info_outline,
        };
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(resolvedIcon, color: muted, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: context.text.bodyMedium?.copyWith(
                      color: muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: context.text.bodySmall?.copyWith(
                    color: muted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}

/// Primary call-to-action with a built-in busy state — every form's submit
/// button, so "Submitting…" looks the same everywhere.
class SubmitButton extends StatelessWidget {
  const SubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.busyLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final String? busyLabel;

  @override
  Widget build(BuildContext context) {
    final onPrimary = context.colors.onPrimary;
    return FilledButton.icon(
      onPressed: busy ? null : onPressed,
      icon: busy
          ? SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: onPrimary,
              ),
            )
          : Icon(icon ?? Icons.check, size: 20),
      label: Text(busy ? (busyLabel ?? label) : label),
    );
  }
}

/// Icon (or custom leading) + title + subtitle + optional trailing — the
/// header row for any record: an asset, a task, a profile.
class EntityHeader extends StatelessWidget {
  const EntityHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconTone,
    this.leading,
    this.trailing,
    this.large = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final StatusTone? iconTone;

  /// Replaces the [icon] tile (e.g. an avatar).
  final Widget? leading;
  final Widget? trailing;

  /// Page-header scale (52px tile, titleLarge) vs. inline (40px, titleMedium).
  final bool large;

  @override
  Widget build(BuildContext context) {
    final lead =
        leading ??
        (icon == null
            ? null
            : IconTile(icon!, tone: iconTone, size: large ? 52 : 40));
    return Row(
      children: [
        if (lead != null) ...[
          lead,
          SizedBox(width: large ? AppSpacing.lg : AppSpacing.md),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: large
                    ? context.text.titleLarge
                    : context.text.titleMedium,
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: context.mutedBody),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.sm),
          trailing!,
        ],
      ],
    );
  }
}

/// A big-number summary card ("3 · Overdue"), optionally tappable.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.value,
    required this.label,
    required this.tone,
    this.onTap,
  });

  /// Null while loading — renders a dash.
  final int? value;
  final String label;
  final StatusTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final v = value;
    return Card(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                v == null ? '–' : '$v',
                style: context.text.headlineSmall?.copyWith(
                  color: tone.foreground(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(label, maxLines: 2, style: context.mutedSmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row of equal [StatCard]s.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.cards});

  final List<StatCard> cards;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            Expanded(child: cards[i]),
          ],
        ],
      ),
    );
  }
}

/// Centered value-over-label figure, laid out in a [Row] of equals —
/// for summary strips inside a card.
class Metric extends StatelessWidget {
  const Metric({
    super.key,
    required this.value,
    required this.label,
    this.tone,
  });

  final String value;
  final String label;

  /// Colours the value; null keeps it neutral.
  final StatusTone? tone;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: context.text.titleLarge?.copyWith(
              color: tone?.foreground(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: context.mutedSmall),
        ],
      ),
    );
  }
}
