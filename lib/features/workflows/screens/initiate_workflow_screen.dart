import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/api/api_exception.dart';
import '../models/workflow_asset_ref.dart';
import '../workflows_providers.dart';

/// FR-067/FR-068 — states an objective for an asset, gets back a workflow id
/// immediately (doesn't block on the evaluation completing). Route:
/// `/workflows/new`.
class InitiateWorkflowScreen extends ConsumerStatefulWidget {
  const InitiateWorkflowScreen({super.key});

  @override
  ConsumerState<InitiateWorkflowScreen> createState() =>
      _InitiateWorkflowScreenState();
}

class _InitiateWorkflowScreenState
    extends ConsumerState<InitiateWorkflowScreen> {
  final _codeController = TextEditingController();
  final _objectiveController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _codeController.dispose();
    _objectiveController.dispose();
    super.dispose();
  }

  Future<void> _lookupAsset() async {
    if (_codeController.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(workflowAssetLookupControllerProvider.notifier)
        .lookup(_codeController.text);
  }

  Future<void> _submit(WorkflowAssetRef asset) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final workflow = await ref
        .read(initiateWorkflowControllerProvider.notifier)
        .submit(assetId: asset.id, objective: _objectiveController.text);

    if (workflow != null && mounted) {
      context.pushReplacement('/workflows/${workflow.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final assetLookup = ref.watch(workflowAssetLookupControllerProvider);
    final submitState = ref.watch(initiateWorkflowControllerProvider);
    final asset = assetLookup.asData?.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Request Evaluation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter the asset code, then state what you\'d like the agent '
                'to evaluate (e.g. "recommend repair, replace or dispose").',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeController,
                enabled: asset == null,
                textInputAction: TextInputAction.search,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Asset code',
                  hintText: 'e.g. AST-00042',
                  border: OutlineInputBorder(),
                ),
                onFieldSubmitted: (_) => _lookupAsset(),
              ),
              const SizedBox(height: 8),
              if (asset == null)
                FilledButton.icon(
                  onPressed: assetLookup.isLoading ? null : _lookupAsset,
                  icon: assetLookup.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(assetLookup.isLoading ? 'Looking up…' : 'Find asset'),
                )
              else
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text('${asset.assetCode} — ${asset.name}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Change asset',
                      onPressed: () {
                        ref
                            .read(workflowAssetLookupControllerProvider.notifier)
                            .reset();
                        _codeController.clear();
                      },
                    ),
                  ),
                ),
              if (assetLookup.hasError) ...[
                const SizedBox(height: 8),
                Text(
                  assetLookup.error is ApiException
                      ? (assetLookup.error as ApiException).message
                      : 'Couldn\'t find that asset.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (asset != null) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _objectiveController,
                  enabled: !submitState.isLoading,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Objective',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                      ? 'State what the agent should evaluate'
                      : null,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: submitState.isLoading
                      ? null
                      : () => _submit(asset),
                  icon: submitState.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.smart_toy_outlined),
                  label: Text(
                    submitState.isLoading ? 'Starting…' : 'Request Evaluation',
                  ),
                ),
                if (submitState.hasError) ...[
                  const SizedBox(height: 12),
                  Text(
                    submitState.error is ApiException
                        ? (submitState.error as ApiException).message
                        : 'Couldn\'t start this evaluation. Try again.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
