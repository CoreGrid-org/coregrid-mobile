import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/api/api_exception.dart';
import '../models/verification_location.dart';
import '../models/verification_task.dart';
import '../verification_providers.dart';

/// FR-059 — complete a verification task by asserting presence, location and
/// condition. No camera/scan step yet (`features/scan/` isn't built) — same
/// stand-in the repo already uses for `features/assets/` manual entry:
/// reached directly from the task list, not via a scan. A mismatch against
/// the register auto-raises a discrepancy server-side (FR-060); "Raise
/// Discrepancy" (FR-061) is offered separately for anything the automatic
/// comparison can't catch. Route: `/verification/:taskId`.
class VerificationTaskDetailScreen extends ConsumerStatefulWidget {
  const VerificationTaskDetailScreen({super.key, required this.taskId});

  final String taskId;

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
  bool _initializedFromTask = false;

  @override
  Widget build(BuildContext context) {
    final taskState = ref.watch(verificationTaskProvider(widget.taskId));
    final locationsState = ref.watch(verificationLocationsProvider);
    final submitState = ref.watch(completeVerificationTaskControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Asset')),
      body: switch (taskState) {
        AsyncData(value: final task?) => _buildBody(
          context,
          task,
          locationsState,
          submitState,
        ),
        AsyncData() => const Center(child: Text('Task not found.')),
        AsyncError(:final error) => Center(
          child: Text(
            error is ApiException
                ? error.message
                : 'Couldn\'t load this task.',
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    VerificationTask task,
    AsyncValue<List<VerificationLocation>> locationsState,
    AsyncValue<void> submitState,
  ) {
    if (!_initializedFromTask) {
      _locationId = task.assertedLocationId;
      _condition = ObservedCondition.tryParse(task.assertedCondition);
      _present = task.assertedPresent ?? true;
      _initializedFromTask = true;
    }

    final alreadyCompleted = task.status == VerificationTaskStatus.completed;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              task.assetName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(task.assetCode),
            const SizedBox(height: 4),
            Text(
              'Campaign: ${task.campaignName} · Due ${_formatDate(task.dueDate)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            if (alreadyCompleted)
              Card(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.4),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('This task has already been completed.'),
                ),
              )
            else ...[
              Card(
                child: SwitchListTile(
                  title: const Text('Asset is present'),
                  subtitle: const Text(
                    'Confirm the physical asset is here.',
                  ),
                  value: _present,
                  onChanged: submitState.isLoading
                      ? null
                      : (value) => setState(() => _present = value),
                ),
              ),
              const SizedBox(height: 12),
              if (_present) ...[
                locationsState.when(
                  data: (locations) => DropdownButtonFormField<String>(
                    initialValue: _locationId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Observed location',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final location in locations)
                        DropdownMenuItem(
                          value: location.id,
                          child: Text(
                            '${location.name} (${location.departmentName})',
                          ),
                        ),
                    ],
                    onChanged: submitState.isLoading
                        ? null
                        : (value) => setState(() => _locationId = value),
                    validator: (value) =>
                        value == null ? 'Select the observed location' : null,
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) =>
                      const Text('Couldn\'t load locations.'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ObservedCondition>(
                  initialValue: _condition,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Observed condition',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final condition in ObservedCondition.values)
                      DropdownMenuItem(
                        value: condition,
                        child: Text(condition.label),
                      ),
                  ],
                  onChanged: submitState.isLoading
                      ? null
                      : (value) => setState(() => _condition = value),
                  validator: (value) =>
                      value == null ? 'Select the observed condition' : null,
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: submitState.isLoading ? null : _submit,
                icon: submitState.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fact_check_outlined),
                label: Text(
                  submitState.isLoading ? 'Submitting…' : 'Submit verification',
                ),
              ),
              if (submitState.hasError) ...[
                const SizedBox(height: 12),
                Text(
                  submitState.error is ApiException
                      ? (submitState.error as ApiException).message
                      : 'Couldn\'t submit this verification. Try again.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () =>
                  context.push('/verification/${task.id}/discrepancy'),
              icon: const Icon(Icons.report_gmailerrorred_outlined),
              label: const Text('Raise Discrepancy Manually'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification submitted.')),
      );
      context.pop();
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
