import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/asset/asset_attribute.dart';

/// Renders an asset's custom attributes purely from [AssetAttributeType].
///
/// The widget is completely data-driven. New asset types and attributes
/// require no changes here.
class AssetAttributeList extends StatelessWidget {
  const AssetAttributeList({super.key, required this.attributes});

  final List<AssetAttribute> attributes;

  static const orange = Color(0xFFFF5A00);
  static const lightOrange = Color(0xFFFFF0E8);
  static const darkText = Color(0xFF202625);
  static const secondaryText = Color(0xFF59635F);

  @override
  Widget build(BuildContext context) {
    // ================================================================
    // NO ATTRIBUTES
    // ================================================================

    if (attributes.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9F8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 20, color: orange),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'This asset type has no custom attributes.',
                style: TextStyle(
                  fontSize: 14,
                  color: secondaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ================================================================
    // ATTRIBUTE LIST
    // ================================================================

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

// ============================================================================
// ATTRIBUTE ROW
// ============================================================================

class _AttributeRow extends StatelessWidget {
  const _AttributeRow({super.key, required this.attribute});

  final AssetAttribute attribute;

  static const secondaryText = Color(0xFF59635F);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9F8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ------------------------------------------------------------
          // ATTRIBUTE NAME
          // ------------------------------------------------------------

          Expanded(
            flex: 2,
            child: Text(
              attribute.name,
              style: const TextStyle(
                fontSize: 14,
                color: secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(width: 16),

          // ------------------------------------------------------------
          // ATTRIBUTE VALUE
          // ------------------------------------------------------------
          Expanded(flex: 3, child: _AttributeValue(attribute: attribute)),
        ],
      ),
    );
  }
}

// ============================================================================
// ATTRIBUTE VALUE
// ============================================================================

class _AttributeValue extends StatelessWidget {
  const _AttributeValue({required this.attribute});

  final AssetAttribute attribute;

  static const orange = Color(0xFFFF5A00);

  // FIX:
  // lightOrange is defined here because this class uses it.
  static const lightOrange = Color(0xFFFFF0E8);

  static const darkText = Color(0xFF202625);
  static const secondaryText = Color(0xFF59635F);

  @override
  Widget build(BuildContext context) {
    const valueStyle = TextStyle(
      fontSize: 14,
      color: darkText,
      fontWeight: FontWeight.w600,
    );

    // ================================================================
    // EMPTY VALUE
    // ================================================================

    if (attribute.isEmpty) {
      return Text(
        attribute.isRequired ? 'Not set' : '—',
        style: const TextStyle(
          fontSize: 14,
          color: secondaryText,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w400,
        ),
      );
    }

    // ================================================================
    // ATTRIBUTE TYPE
    // ================================================================

    switch (attribute.type) {
      // --------------------------------------------------------------
      // BOOLEAN
      // --------------------------------------------------------------

      case AssetAttributeType.boolean:
        final value = attribute.valueBoolean ?? false;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: lightOrange,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                value ? Icons.check_rounded : Icons.close_rounded,
                size: 18,
                color: orange,
              ),
            ),

            const SizedBox(width: 8),

            Text(value ? 'Yes' : 'No', style: valueStyle),
          ],
        );

      // --------------------------------------------------------------
      // DATE
      // --------------------------------------------------------------

      case AssetAttributeType.date:
        final date = attribute.valueDate;

        return Text(
          date == null ? '—' : DateFormat.yMMMMd().format(date),
          style: valueStyle,
        );

      // --------------------------------------------------------------
      // NUMBER
      // --------------------------------------------------------------

      case AssetAttributeType.number:
        final number = attribute.valueNumber;

        return Text(
          number == null ? '—' : NumberFormat.decimalPattern().format(number),
          style: valueStyle,
        );

      // --------------------------------------------------------------
      // TEXT
      // --------------------------------------------------------------

      case AssetAttributeType.text:
        return Text(attribute.valueText ?? '—', style: valueStyle);

      // --------------------------------------------------------------
      // UNKNOWN
      // --------------------------------------------------------------

      case AssetAttributeType.unknown:
        // Forward compatibility:
        // Display whichever scalar value the API returned.
        return Text(
          attribute.valueText ??
              attribute.valueNumber?.toString() ??
              attribute.valueBoolean?.toString() ??
              attribute.valueDate?.toIso8601String() ??
              '—',
          style: valueStyle,
        );
    }
  }
}
