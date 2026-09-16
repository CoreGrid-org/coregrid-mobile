import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/api/api_exception.dart';
import '../../assets_providers.dart';
import '../../models/asset/asset_condition.dart';

/// Bottom sheet for recording a new asset condition (FR-029). The scale is
/// exactly the SRS's five points; the change is written to asset history by
/// the API, not here.
///
/// Returns `true` through the sheet's `Navigator.pop` when the update
/// succeeded, so the caller can show a confirmation.
class ConditionUpdateSheet extends ConsumerStatefulWidget {
  const ConditionUpdateSheet({
    super.key,
    required this.assetId,
    required this.current,
  });

  final String assetId;
  final AssetCondition? current;

  static Future<bool?> show(
    BuildContext context, {
    required String assetId,
    required AssetCondition? current,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => ConditionUpdateSheet(assetId: assetId, current: current),
    );
  }

  @override
  ConsumerState<ConditionUpdateSheet> createState() =>
      _ConditionUpdateSheetState();
}

class _ConditionUpdateSheetState extends ConsumerState<ConditionUpdateSheet> {
  static const orange = Color(0xFFFF5A00);
  static const darkText = Color(0xFF202625);
  static const secondaryText = Color(0xFF59635F);

  AssetCondition? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  Future<void> _submit() async {
    final selected = _selected;
    if (selected == null) return;

    final ok = await ref
        .read(conditionUpdateControllerProvider.notifier)
        .submit(assetId: widget.assetId, condition: selected);

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      final error = ref.read(conditionUpdateControllerProvider).error;
      final message = error is ApiException
          ? error.message
          : 'Couldn\'t update the condition. Try again.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = ref.watch(conditionUpdateControllerProvider).isLoading;
    final unchanged = _selected == widget.current;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFD7DCD9),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Text(
              'Record condition',
              style: const TextStyle(
                color: darkText,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Set the asset\'s condition as you\'ve just inspected it. '
              'The change is added to the asset history.',
              style: const TextStyle(
                color: secondaryText,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            for (final condition in AssetCondition.values) ...[
              _ConditionOption(
                condition: condition,
                selected: _selected == condition,
                enabled: !isSubmitting,
                onTap: () => setState(() => _selected = condition),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: orange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFE1E3E2),
                  disabledForegroundColor: const Color(0xFF8B9290),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: (isSubmitting || _selected == null || unchanged)
                    ? null
                    : _submit,
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(unchanged ? 'No change' : 'Save condition'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConditionOption extends StatelessWidget {
  const _ConditionOption({
    required this.condition,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final AssetCondition condition;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  static const orange = Color(0xFFFF5A00);
  static const lightOrange = Color(0xFFFFF0E8);
  static const darkText = Color(0xFF202625);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? lightOrange : const Color(0xFFF8F9F8),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? orange : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? orange : const Color(0xFF59635F),
                size: 23,
              ),
              const SizedBox(width: 12),
              Text(
                condition.label,
                style: const TextStyle(
                  color: darkText,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
