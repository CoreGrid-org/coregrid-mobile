import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/api/api_exception.dart';
import '../../../../shared/widgets/ui.dart';
import '../../assets_providers.dart';
import '../../models/asset/asset_condition.dart';

/// Bottom sheet for recording a new asset condition.
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
      builder: (_) => ConditionUpdateSheet(assetId: assetId, current: current),
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
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Record condition', style: context.text.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Set the asset\'s condition as you\'ve just inspected it. '
              'The change is added to the asset history.',
              style: context.mutedBody,
            ),
            const SizedBox(height: AppSpacing.lg),
            RadioGroup<AssetCondition>(
              groupValue: _selected,
              onChanged: (c) {
                if (!isSubmitting && c != null) setState(() => _selected = c);
              },
              child: ClayCard(
                child: Column(
                  children: [
                    for (var i = 0; i < AssetCondition.values.length; i++) ...[
                      if (i > 0) const Divider(indent: AppSpacing.lg),
                      RadioListTile<AssetCondition>(
                        value: AssetCondition.values[i],
                        enabled: !isSubmitting,
                        title: Text(AssetCondition.values[i].label),
                        secondary: AssetCondition.values[i] == widget.current
                            ? const StatusPill('Current')
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SubmitButton(
              label: unchanged ? 'No change' : 'Save condition',
              busyLabel: 'Saving…',
              icon: Icons.check_rounded,
              busy: isSubmitting,
              onPressed: (_selected == null || unchanged) ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
