import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/ui.dart';
import '../../models/asset/asset_attribute.dart';

/// Renders an asset's custom attributes purely from [AssetAttributeType].
///
/// The widget is completely data-driven. New asset types and attributes
/// require no changes here.
class AssetAttributeList extends StatelessWidget {
  const AssetAttributeList({super.key, required this.attributes});

  final List<AssetAttribute> attributes;

  @override
  Widget build(BuildContext context) {
    if (attributes.isEmpty) {
      return const Notice(message: 'This asset type has no custom attributes.');
    }
    return ListCard(
      children: [
        for (final attribute in attributes)
          _AttributeRow(
            key: ValueKey(attribute.definitionId),
            attribute: attribute,
          ),
      ],
    );
  }
}

class _AttributeRow extends StatelessWidget {
  const _AttributeRow({super.key, required this.attribute});

  final AssetAttribute attribute;

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
          Expanded(
            flex: 2,
            child: Text(attribute.name, style: context.mutedBody),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: _AttributeValue(attribute: attribute),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttributeValue extends StatelessWidget {
  const _AttributeValue({required this.attribute});

  final AssetAttribute attribute;

  @override
  Widget build(BuildContext context) {
    final valueStyle = context.text.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );

    if (attribute.isEmpty) {
      return Text(
        attribute.isRequired ? 'Not set' : '—',
        style: context.text.bodyMedium?.copyWith(
          color: context.colors.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    switch (attribute.type) {
      case AssetAttributeType.boolean:
        final value = attribute.valueBoolean ?? false;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.check_circle_rounded : Icons.cancel_outlined,
              size: 18,
              color: value
                  ? StatusTone.success.foreground(context)
                  : context.colors.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xs + 2),
            Text(value ? 'Yes' : 'No', style: valueStyle),
          ],
        );

      case AssetAttributeType.date:
        final date = attribute.valueDate;
        return Text(
          date == null ? '—' : formatDate(date),
          textAlign: TextAlign.end,
          style: valueStyle,
        );

      case AssetAttributeType.number:
        final number = attribute.valueNumber;
        return Text(
          number == null ? '—' : NumberFormat.decimalPattern().format(number),
          textAlign: TextAlign.end,
          style: valueStyle,
        );

      case AssetAttributeType.text:
        return Text(
          attribute.valueText ?? '—',
          textAlign: TextAlign.end,
          style: valueStyle,
        );

      case AssetAttributeType.unknown:
        // Forward compatibility: show whichever scalar the API returned.
        return Text(
          attribute.valueText ??
              attribute.valueNumber?.toString() ??
              attribute.valueBoolean?.toString() ??
              attribute.valueDate?.toIso8601String() ??
              '—',
          textAlign: TextAlign.end,
          style: valueStyle,
        );
    }
  }
}
