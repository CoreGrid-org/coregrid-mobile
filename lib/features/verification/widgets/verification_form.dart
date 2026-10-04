import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/ui.dart';
import '../models/verification_task.dart';
import '../verification_providers.dart';

/// The physical-verification assertion — presence, observed location,
/// observed condition — shared by task-bound verification (FR-059,
/// `PATCH /api/verification-tasks/{id}/complete`) and ad-hoc verification
/// (FR-031, `POST /api/assets/{id}/verify`). Both endpoints run the same
/// server-side comparison (FR-060); only the submit call differs, so the
/// caller owns submission and must place this inside a [Form].
class VerificationForm extends StatelessWidget {
  const VerificationForm({
    super.key,
    required this.present,
    required this.onPresentChanged,
    required this.locationId,
    required this.onLocationChanged,
    required this.condition,
    required this.onConditionChanged,
    this.enabled = true,
    this.header,
  });

  final bool present;
  final ValueChanged<bool> onPresentChanged;
  final String? locationId;
  final ValueChanged<String?> onLocationChanged;
  final ObservedCondition? condition;
  final ValueChanged<ObservedCondition> onConditionChanged;
  final bool enabled;

  /// Shown above the questions (e.g. the scan-to-confirm step).
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null) ...[
              header!,
              const SizedBox(height: AppSpacing.xl),
            ],
            const _Question('Is the asset here?'),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Present'),
                  icon: Icon(Icons.check_circle_outline),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Not found'),
                  icon: Icon(Icons.help_outline),
                ),
              ],
              selected: {present},
              onSelectionChanged: enabled
                  ? (s) => onPresentChanged(s.first)
                  : null,
            ),
            if (present) ...[
              const SizedBox(height: AppSpacing.xl),
              const _Question('Where is it?'),
              _LocationField(
                locationId: locationId,
                onChanged: enabled ? onLocationChanged : null,
              ),
              const SizedBox(height: AppSpacing.xl),
              const _Question('What condition is it in?'),
              _ConditionField(
                value: condition,
                enabled: enabled,
                onChanged: onConditionChanged,
              ),
            ] else ...[
              const SizedBox(height: AppSpacing.lg),
              const Notice(
                tone: StatusTone.warning,
                message:
                    'Submitting as not found records the asset as missing — '
                    'CoreGrid raises the discrepancy automatically.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(text, style: context.text.titleSmall),
  );
}

class _LocationField extends ConsumerWidget {
  const _LocationField({required this.locationId, required this.onChanged});

  final String? locationId;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(verificationLocationsProvider)) {
      AsyncData(:final value) => DropdownButtonFormField<String>(
        initialValue: value.any((l) => l.id == locationId) ? locationId : null,
        isExpanded: true,
        decoration: const InputDecoration(
          hintText: 'Select location',
          prefixIcon: Icon(Icons.place_outlined),
        ),
        items: [
          for (final l in value)
            DropdownMenuItem(
              value: l.id,
              child: Text(
                '${l.name} · ${l.departmentName}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: onChanged,
        validator: (v) => v == null ? 'Select the observed location' : null,
      ),
      AsyncError(:final error) => Notice(
        tone: StatusTone.danger,
        message: errorMessageFor(error, fallback: 'Couldn\'t load locations.'),
      ),
      _ => const LinearProgressIndicator(),
    };
  }
}

/// Five-point condition scale as choice chips, validated as a form field.
class _ConditionField extends StatelessWidget {
  const _ConditionField({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final ObservedCondition? value;
  final bool enabled;
  final ValueChanged<ObservedCondition> onChanged;

  @override
  Widget build(BuildContext context) {
    return FormField<ObservedCondition>(
      initialValue: value,
      validator: (_) => value == null ? 'Select the observed condition' : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final c in ObservedCondition.values)
                ChoiceChip(
                  label: Text(c.label),
                  selected: value == c,
                  onSelected: enabled
                      ? (_) {
                          onChanged(c);
                          field.didChange(c);
                        }
                      : null,
                ),
            ],
          ),
          if (field.errorText case final error?)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm, left: 4),
              child: Text(
                error,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
