import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/api/api_exception.dart';
import '../../../shared/org_config/org_config_models.dart';
import '../../../shared/org_config/org_config_providers.dart';
import '../models/initiate_transfer_request.dart';
import '../transfers_providers.dart';

/// Form screen for FR-043: Initiate Transfer Request.
///
/// Collects:
/// - Asset ID (UUID)
/// - Destination department (from [departmentsProvider], pre-checked to exist)
/// - Destination location (from [locationsForDepartmentProvider], cascaded)
///
/// Submits via [initiateTransferControllerProvider]. On success, pushes to
/// the newly created transfer's detail screen.
class InitiateTransferScreen extends ConsumerStatefulWidget {
  const InitiateTransferScreen({super.key});

  @override
  ConsumerState<InitiateTransferScreen> createState() =>
      _InitiateTransferScreenState();
}

class _InitiateTransferScreenState
    extends ConsumerState<InitiateTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _assetIdController = TextEditingController();

  DepartmentDto? _selectedDepartment;
  LocationDto? _selectedLocation;

  @override
  void dispose() {
    _assetIdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final request = InitiateTransferRequest(
      assetId: _assetIdController.text.trim(),
      toDepartmentId: _selectedDepartment!.id,
      toLocationId: _selectedLocation!.id,
    );

    final created = await ref
        .read(initiateTransferControllerProvider.notifier)
        .submit(request);

    if (!mounted) return;

    final state = ref.read(initiateTransferControllerProvider);
    if (state.hasError) return; // error shown inline

    // Navigate to the newly created transfer's detail screen.
    if (created != null) {
      context.pushReplacement('/transfers/');
    } else {
      context.pushReplacement('/transfers');
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(initiateTransferControllerProvider);
    final isSubmitting = controller.isLoading;

    final departments = ref.watch(departmentsProvider);

    // When department changes, reset location selection and reload locations.
    final locations = _selectedDepartment != null
        ? ref.watch(
            locationsForDepartmentProvider(_selectedDepartment!.id),
          )
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('New Transfer Request')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Asset ID
            TextFormField(
              controller: _assetIdController,
              enabled: !isSubmitting,
              decoration: const InputDecoration(
                labelText: 'Asset ID',
                hintText: 'Paste or type the asset UUID',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Asset ID is required'
                  : null,
            ),
            const SizedBox(height: 16),

            // Destination department
            switch (departments) {
              AsyncData(:final value) => DropdownButtonFormField<DepartmentDto>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Destination department',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                  initialValue: _selectedDepartment,
                  items: value
                      .map((d) => DropdownMenuItem(
                            value: d,
                            child: Text(d.name),
                          ))
                      .toList(),
                  onChanged: isSubmitting
                      ? null
                      : (dept) => setState(() {
                            _selectedDepartment = dept;
                            _selectedLocation = null;
                          }),
                  validator: (_) => _selectedDepartment == null
                      ? 'Select a destination department'
                      : null,
                ),
              AsyncError() => _FieldError(
                  'Could not load departments.',
                  onRetry: () => ref.invalidate(departmentsProvider),
                ),
              _ => const _FieldLoading(label: 'Loading departments.'),
            },
            const SizedBox(height: 16),

            // Destination location (cascade)
            if (_selectedDepartment != null)
              switch (locations!) {
                AsyncData(:final value) => DropdownButtonFormField<LocationDto>(
                    key: ValueKey('loc_'),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Destination location',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                    initialValue: _selectedLocation,
                    items: value
                        .map((l) => DropdownMenuItem(
                              value: l,
                              child: Text(l.name),
                            ))
                        .toList(),
                    onChanged: isSubmitting
                        ? null
                        : (loc) => setState(() => _selectedLocation = loc),
                    validator: (_) => _selectedLocation == null
                        ? 'Select a destination location'
                        : null,
                  ),
                AsyncError() => _FieldError(
                    'Could not load locations.',
                    onRetry: () => ref.invalidate(
                      locationsForDepartmentProvider(_selectedDepartment!.id),
                    ),
                  ),
                _ => const _FieldLoading(label: 'Loading locations.'),
              }
            else
              DropdownButtonFormField<LocationDto>(
                decoration: const InputDecoration(
                  labelText: 'Destination location',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.place_outlined),
                ),
                items: const [],
                onChanged: null,
                hint: const Text('Select a department first'),
              ),

            const SizedBox(height: 24),

            // Error banner
            if (controller.hasError) ...[
              _ErrorBanner(
                message: controller.error is ApiException
                    ? (controller.error as ApiException).message
                    : 'Could not submit transfer request. Please try again.',
              ),
              const SizedBox(height: 16),
            ],

            // Submit
            FilledButton.icon(
              onPressed: isSubmitting ? null : _submit,
              icon: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.local_shipping_outlined),
              label: Text(isSubmitting ? 'Submitting.' : 'Submit Transfer Request'),
            ),
          ],
        ),
      ),
    );
  }
}

// Private helper widgets

class _FieldLoading extends StatelessWidget {
  const _FieldLoading({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: const LinearProgressIndicator(),
      );
}

class _FieldError extends StatelessWidget {
  const _FieldError(this.message, {required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(Icons.error_outline,
              color: Theme.of(context).colorScheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Card(
      color: color.withValues(alpha: 0.10),
      child: ListTile(
        leading: Icon(Icons.info_outline, color: color),
        title: const Text('Submission failed'),
        subtitle: Text(message),
      ),
    );
  }
}
