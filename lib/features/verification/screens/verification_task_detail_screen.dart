import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/ui.dart';
import '../../scan/screens/scan_asset_screen.dart';
import '../models/verification_task.dart';
import '../verification_providers.dart';
import '../widgets/verification_form.dart';

/// Complete one verification task (FR-059): **scan the asset** to prove the
/// officer is physically at it, then assert presence, location and
/// condition. The backend compares the assertion with the register and
/// raises any discrepancy itself (FR-060).
///
/// A scan is required only to assert "Present" — a missing asset can't be
/// scanned. [scanned] is set when the officer arrived from "Scan to verify",
/// where the identifying scan already happened.
class VerificationTaskDetailScreen extends ConsumerStatefulWidget {
  const VerificationTaskDetailScreen({
    super.key,
    required this.taskId,
    this.scanned = false,
  });

  final String taskId;
  final bool scanned;

  @override
  ConsumerState<VerificationTaskDetailScreen> createState() =>
      _VerificationTaskDetailScreenState();
}

class _VerificationTaskDetailScreenState
    extends ConsumerState<VerificationTaskDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _present = true;
  String? _locationId;
  ObservedCondition? _condition;
  late bool _identityConfirmed = widget.scanned;
  String? _scanMismatch;
  bool _initializedFromTask = false;

  Future<void> _scanToConfirm(VerificationTask task) async {
    final asset = await identifyAssetByScan(context);
    if (asset == null || !mounted) return;
    setState(() {
      _identityConfirmed = asset.id == task.assetId;
      _scanMismatch = _identityConfirmed
          ? null
          : 'That label is ${asset.assetCode} (${asset.name}), not '
                '${task.assetCode}. Find the right asset and scan again.';
    });
  }

  Future<void> _submit() async {
    if (_present && !_identityConfirmed) {
      setState(
        () => _scanMismatch =
            'Scan the asset\'s QR label before marking it present.',
      );
      return;
    }
    if (_present && !(_formKey.currentState?.validate() ?? false)) return;

    final result = await ref
        .read(completeVerificationTaskControllerProvider.notifier)
        .submit(
          taskId: widget.taskId,
          assertedPresent: _present,
          assertedLocationId: _present ? _locationId : null,
          assertedCondition: _present ? _condition?.apiValue : null,
        );

    if (result != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Verification submitted.')));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify asset')),
      body: switch (ref.watch(verificationTaskProvider(widget.taskId))) {
        AsyncData(value: final task?) => _body(task),
        AsyncData() => const MessageView(
          icon: Icons.search_off_rounded,
          title: 'Task not found',
          message: 'It may have been reassigned or the campaign closed.',
        ),
        AsyncError(:final error) => ErrorView(
          error: error,
          title: 'Couldn\'t load this task',
          onRetry: () => ref.invalidate(myVerificationTasksProvider),
        ),
        _ => const LoadingView(),
      },
    );
  }

  Widget _body(VerificationTask task) {
    if (!_initializedFromTask) {
      _locationId = task.assertedLocationId;
      _condition = ObservedCondition.tryParse(task.assertedCondition);
      _present = task.assertedPresent ?? true;
      _initializedFromTask = true;
    }

    final submitState = ref.watch(completeVerificationTaskControllerProvider);
    final busy = submitState.isLoading;

    return SingleChildScrollView(
      padding: AppSpacing.pageInsets,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TaskHeader(task: task),
          if (!task.isPending)
            _CompletedSummary(task: task)
          else
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeader('Your observation'),
                  VerificationForm(
                    enabled: !busy,
                    present: _present,
                    onPresentChanged: (v) => setState(() => _present = v),
                    locationId: _locationId,
                    onLocationChanged: (v) => setState(() => _locationId = v),
                    condition: _condition,
                    onConditionChanged: (v) => setState(() => _condition = v),
                    header: _present
                        ? _ScanConfirmation(
                            confirmed: _identityConfirmed,
                            assetCode: task.assetCode,
                            mismatch: _scanMismatch,
                            onScan: busy ? null : () => _scanToConfirm(task),
                          )
                        : null,
                  ),
                  if (submitState.hasError) ...[
                    const SizedBox(height: AppSpacing.md),
                    Notice(
                      tone: StatusTone.danger,
                      message: errorMessageFor(
                        submitState.error!,
                        fallback:
                            'Couldn\'t submit this verification. Try again.',
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  SubmitButton(
                    label: 'Submit verification',
                    busyLabel: 'Submitting…',
                    icon: Icons.fact_check_outlined,
                    busy: busy,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () =>
                context.push('/verification/${task.id}/discrepancy'),
            icon: const Icon(Icons.report_gmailerrorred_outlined, size: 20),
            label: const Text('Raise a discrepancy'),
          ),
        ],
      ),
    );
  }
}

/// Step one of FR-059: prove presence by scanning the asset's own label.
class _ScanConfirmation extends StatelessWidget {
  const _ScanConfirmation({
    required this.confirmed,
    required this.assetCode,
    required this.mismatch,
    required this.onScan,
  });

  final bool confirmed;
  final String assetCode;
  final String? mismatch;
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    if (confirmed) {
      return Notice(
        tone: StatusTone.success,
        icon: Icons.qr_code_2,
        message: 'Identity confirmed — you scanned $assetCode.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Notice(
          tone: mismatch == null ? StatusTone.info : StatusTone.danger,
          icon: Icons.qr_code_scanner,
          title: 'Scan to confirm',
          message:
              mismatch ??
              'Scan the QR label on $assetCode to confirm you\'re at the '
                  'right asset.',
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.tonalIcon(
          onPressed: onScan,
          icon: const Icon(Icons.qr_code_scanner, size: 20),
          label: Text(mismatch == null ? 'Scan asset' : 'Scan again'),
        ),
      ],
    );
  }
}

class _TaskHeader extends StatelessWidget {
  const _TaskHeader({required this.task});

  final VerificationTask task;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: EntityHeader(
              large: true,
              icon: Icons.inventory_2_outlined,
              title: task.assetName,
              subtitle: task.assetCode,
            ),
          ),
          const Divider(),
          InfoRow(
            icon: Icons.flag_outlined,
            label: 'Campaign',
            value: task.campaignName,
          ),
          InfoRow(
            icon: Icons.event_outlined,
            label: task.isPending ? describeDue(task.dueDate) : 'Due',
            value: formatDate(task.dueDate),
          ),
          const Divider(),
          RecordTile(
            icon: Icons.description_outlined,
            title: 'Open asset record',
            onTap: () => context.push('/assets/${task.assetId}'),
          ),
        ],
      ),
    );
  }
}

class _CompletedSummary extends StatelessWidget {
  const _CompletedSummary({required this.task});

  final VerificationTask task;

  @override
  Widget build(BuildContext context) {
    final condition = ObservedCondition.tryParse(task.assertedCondition);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xl),
        Notice(
          tone: StatusTone.success,
          title: 'Verified',
          message: task.completedAt == null
              ? 'This task has already been completed.'
              : 'Completed ${formatDateTime(task.completedAt!)}.',
        ),
        const SizedBox(height: AppSpacing.md),
        ListCard(
          children: [
            InfoRow(
              label: 'Asset present',
              value: switch (task.assertedPresent) {
                true => 'Yes',
                false => 'No',
                null => '—',
              },
            ),
            if (condition != null)
              InfoRow(label: 'Condition', value: condition.label),
          ],
        ),
      ],
    );
  }
}
