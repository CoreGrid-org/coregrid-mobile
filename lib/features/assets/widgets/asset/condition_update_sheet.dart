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
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) =>
          ConditionUpdateSheet(assetId: assetId, current: current),
    );
  }

  @override
  ConsumerState<ConditionUpdateSheet> createState() =>
      _ConditionUpdateSheetState();
}

class _ConditionUpdateSheetState extends ConsumerState<ConditionUpdateSheet> {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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
            Text(
              'Record condition',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Set the asset\'s condition as you\'ve just inspected it. '
              'The change is added to the asset history.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            RadioGroup<AssetCondition>(
              groupValue: _selected,
              onChanged: isSubmitting
                  ? (_) {}
                  : (value) => setState(() => _selected = value),
              child: Column(
                children: [
                  for (final condition in AssetCondition.values)
                    RadioListTile<AssetCondition>(
                      value: condition,
                      title: Text(condition.label),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: (isSubmitting || _selected == null || unchanged)
                  ? null
                  : _submit,
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(unchanged ? 'No change' : 'Save condition'),
            ),
          ],
        ),
      ),
    );
  }
}
