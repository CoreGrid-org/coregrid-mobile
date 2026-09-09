import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/asset/asset_attribute.dart';

/// Renders an asset's custom attributes purely from their [AssetAttributeType]
/// — the concrete realisation of FR-020 in this app. There is no `switch` on
/// attribute *name* anywhere here; a new asset type with new attributes needs
/// zero changes to this widget.
class AssetAttributeList extends StatelessWidget {
  const AssetAttributeList({super.key, required this.attributes});

  final List<AssetAttribute> attributes;

  @override
  Widget build(BuildContext context) {
    if (attributes.isEmpty) {
      return Text(
        'This asset type has no custom attributes.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              attribute.name,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: _AttributeValue(attribute: attribute),
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
    final style = Theme.of(context).textTheme.bodyMedium;

    if (attribute.isEmpty) {
      return Text(
        attribute.isRequired ? 'Not set' : '—',
        style: style?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    switch (attribute.type) {
      case AssetAttributeType.boolean:
        final value = attribute.valueBoolean ?? false;
        return Row(
          children: [
            Icon(
              value ? Icons.check_circle_outline : Icons.cancel_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(value ? 'Yes' : 'No', style: style),
          ],
        );
      case AssetAttributeType.date:
        final date = attribute.valueDate;
        return Text(
          date == null ? '—' : DateFormat.yMMMMd().format(date),
          style: style,
        );
      case AssetAttributeType.number:
        final number = attribute.valueNumber;
        return Text(
          number == null ? '—' : NumberFormat.decimalPattern().format(number),
          style: style,
        );
      case AssetAttributeType.text:
        return Text(attribute.valueText ?? '—', style: style);
      case AssetAttributeType.unknown:
        // Forward-compatibility: an attribute type this build doesn't know.
        // Show whatever scalar came back rather than dropping it.
        return Text(
          attribute.valueText ??
              attribute.valueNumber?.toString() ??
              attribute.valueBoolean?.toString() ??
              attribute.valueDate?.toIso8601String() ??
              '—',
          style: style,
        );
    }
  }
}
