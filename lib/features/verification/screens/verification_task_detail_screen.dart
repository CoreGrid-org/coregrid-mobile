import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/api/api_exception.dart';
import '../models/verification_location.dart';
import '../models/verification_task.dart';
import '../verification_providers.dart';

/// Screen for completing a verification task — asserts presence, location and condition.
class VerificationTaskDetailScreen extends ConsumerStatefulWidget {
  const VerificationTaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  static const Color orange = Color(0xFFFF5A00);
  static const Color lightOrange = Color(0xFFFFF0E8);
  static const Color cardFill = Color(0xFFFFFBF9);
  static const Color cardBorder = Color(0xFFFFE2D3);
  static const Color darkText = Color(0xFF202625);
  static const Color secondaryText = Color(0xFF59635F);

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: const Text(
          'Verify Asset',
          style: TextStyle(
            color: VerificationTaskDetailScreen.darkText,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(
          color: VerificationTaskDetailScreen.darkText,
        ),
      ),
      body: switch (taskState) {
        AsyncData(value: final task?) => _buildBody(
          context,
          task,
          locationsState,
          submitState,
        ),
        AsyncData() => const Center(
          child: Text(
            'Task not found.',
            style: TextStyle(color: VerificationTaskDetailScreen.secondaryText),
          ),
        ),
        AsyncError(:final error) => Center(
          child: Text(
            error is ApiException ? error.message : 'Couldn\'t load this task.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        _ => const Center(
          child: CircularProgressIndicator(
            color: VerificationTaskDetailScreen.orange,
          ),
        ),
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
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TaskDetailHeader(task: task),
            const SizedBox(height: 24),
            if (alreadyCompleted)
              const _AlreadyCompletedCard()
            else
              _FormSectionCard(
                present: _present,
                onPresentChanged: submitState.isLoading
                    ? null
                    : (val) => setState(() => _present = val),
                locationId: _locationId,
                onLocationChanged: submitState.isLoading
                    ? null
                    : (val) => setState(() => _locationId = val),
                locationsState: locationsState,
                condition: _condition,
                onConditionChanged: submitState.isLoading
                    ? null
                    : (val) => setState(() => _condition = val),
                onSubmit: submitState.isLoading ? null : _submit,
                isSubmitting: submitState.isLoading,
                errorMessage: submitState.hasError
                    ? (submitState.error is ApiException
                          ? (submitState.error as ApiException).message
                          : 'Couldn\'t submit this verification. Try again.')
                    : null,
              ),
            const SizedBox(height: 20),
            _RaiseDiscrepancyButton(
              onPressed: () =>
                  context.push('/verification/${task.id}/discrepancy'),
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
        const SnackBar(
          content: Text('Verification submitted.'),
          duration: Duration(seconds: 5),
        ),
      );
      context.pop();
    }
  }
}

class _TaskDetailHeader extends StatelessWidget {
  const _TaskDetailHeader({required this.task});

  final VerificationTask task;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: VerificationTaskDetailScreen.lightOrange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.fact_check_rounded,
                size: 32,
                color: VerificationTaskDetailScreen.orange,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.assetName,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: VerificationTaskDetailScreen.darkText,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    task.assetCode,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: VerificationTaskDetailScreen.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Campaign: ${task.campaignName} · Due ${_formatDate(task.dueDate)}',
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
            color: Color(0xFF7A827F),
          ),
        ),
      ],
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _AlreadyCompletedCard extends StatelessWidget {
  const _AlreadyCompletedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: VerificationTaskDetailScreen.lightOrange,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: Color(0xFF00897B), size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'This task has already been completed.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: VerificationTaskDetailScreen.darkText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormSectionCard extends StatelessWidget {
  const _FormSectionCard({
    required this.present,
    required this.onPresentChanged,
    required this.locationId,
    required this.onLocationChanged,
    required this.locationsState,
    required this.condition,
    required this.onConditionChanged,
    required this.onSubmit,
    required this.isSubmitting,
    this.errorMessage,
  });

  final bool present;
  final ValueChanged<bool>? onPresentChanged;
  final String? locationId;
  final ValueChanged<String?>? onLocationChanged;
  final AsyncValue<List<VerificationLocation>> locationsState;
  final ObservedCondition? condition;
  final ValueChanged<ObservedCondition?>? onConditionChanged;
  final VoidCallback? onSubmit;
  final bool isSubmitting;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: VerificationTaskDetailScreen.cardFill,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: VerificationTaskDetailScreen.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PresenceSwitchTile(present: present, onChanged: onPresentChanged),
          if (present) ...[
            const SizedBox(height: 16),
            _LocationDropdown(
              locationId: locationId,
              locationsState: locationsState,
              onChanged: onLocationChanged,
            ),
            const SizedBox(height: 14),
            _ConditionDropdown(
              condition: condition,
              onChanged: onConditionChanged,
            ),
          ],
          const SizedBox(height: 20),
          _SubmitButton(onSubmit: onSubmit, isSubmitting: isSubmitting),
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              errorMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PresenceSwitchTile extends StatelessWidget {
  const _PresenceSwitchTile({required this.present, required this.onChanged});

  final bool present;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7E6)),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        activeTrackColor: VerificationTaskDetailScreen.orange,
        title: const Text(
          'Asset is present',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: VerificationTaskDetailScreen.darkText,
          ),
        ),
        subtitle: const Text(
          'Confirm the physical asset is here.',
          style: TextStyle(
            fontSize: 13.5,
            color: VerificationTaskDetailScreen.secondaryText,
          ),
        ),
        value: present,
        onChanged: onChanged,
      ),
    );
  }
}

class _LocationDropdown extends StatelessWidget {
  const _LocationDropdown({
    required this.locationId,
    required this.locationsState,
    required this.onChanged,
  });

  final String? locationId;
  final AsyncValue<List<VerificationLocation>> locationsState;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return locationsState.when(
      data: (locations) => DropdownButtonFormField<String>(
        initialValue: locationId,
        isExpanded: true,
        style: const TextStyle(
          fontSize: 15,
          color: VerificationTaskDetailScreen.darkText,
        ),
        decoration: _inputDecoration('Observed location'),
        items: [
          for (final location in locations)
            DropdownMenuItem(
              value: location.id,
              child: Text('${location.name} (${location.departmentName})'),
            ),
        ],
        onChanged: onChanged,
        validator: (value) =>
            value == null ? 'Select the observed location' : null,
      ),
      loading: () => const LinearProgressIndicator(
        color: VerificationTaskDetailScreen.orange,
      ),
      error: (error, _) => const Text(
        'Couldn\'t load locations.',
        style: TextStyle(color: VerificationTaskDetailScreen.secondaryText),
      ),
    );
  }
}

class _ConditionDropdown extends StatelessWidget {
  const _ConditionDropdown({required this.condition, required this.onChanged});

  final ObservedCondition? condition;
  final ValueChanged<ObservedCondition?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<ObservedCondition>(
      initialValue: condition,
      isExpanded: true,
      style: const TextStyle(
        fontSize: 15,
        color: VerificationTaskDetailScreen.darkText,
      ),
      decoration: _inputDecoration('Observed condition'),
      items: [
        for (final item in ObservedCondition.values)
          DropdownMenuItem(value: item, child: Text(item.label)),
      ],
      onChanged: onChanged,
      validator: (value) =>
          value == null ? 'Select the observed condition' : null,
    );
  }
}

InputDecoration _inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(
      color: VerificationTaskDetailScreen.secondaryText,
      fontSize: 14,
    ),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFE5E7E6)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFE5E7E6)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(
        color: VerificationTaskDetailScreen.orange,
        width: 1.5,
      ),
    ),
  );
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.onSubmit, required this.isSubmitting});

  final VoidCallback? onSubmit;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: FilledButton.icon(
        onPressed: onSubmit,
        style: FilledButton.styleFrom(
          backgroundColor: VerificationTaskDetailScreen.orange,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.fact_check_outlined, size: 22),
        label: Text(
          isSubmitting ? 'Submitting…' : 'Submit verification',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _RaiseDiscrepancyButton extends StatelessWidget {
  const _RaiseDiscrepancyButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: VerificationTaskDetailScreen.orange,
          backgroundColor: Colors.white,
          side: const BorderSide(
            color: VerificationTaskDetailScreen.orange,
            width: 1.4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: const Icon(Icons.report_gmailerrorred_outlined, size: 22),
        label: const Text(
          'Raise Discrepancy Manually',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
