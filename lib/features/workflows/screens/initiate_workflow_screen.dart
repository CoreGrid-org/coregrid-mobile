import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/ui.dart';
import '../../scan/screens/scan_asset_screen.dart';
import '../models/workflow_asset_ref.dart';
import '../workflows_providers.dart';

/// Screen to initiate a new agent workflow for an asset. Route: `/workflows/new`.
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

  Future<void> _scanAsset() async {
    final scanned = await identifyAssetByScan(context);
    if (!mounted || scanned == null) return;
    ref
        .read(workflowAssetLookupControllerProvider.notifier)
        .select(
          WorkflowAssetRef(
            id: scanned.id,
            assetCode: scanned.assetCode,
            name: scanned.name,
          ),
        );
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
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: AppSpacing.pageInsets,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'The CoreGrid agent reviews the asset\'s history and recommends '
                'what to do next — for example repair, replace or dispose.',
                style: context.mutedBody,
              ),
              const SizedBox(height: AppSpacing.xl),
              const _Step(number: 1, title: 'Choose the asset'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: asset == null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _codeController,
                              textInputAction: TextInputAction.search,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'Asset code',
                                hintText: 'e.g. AST-00042',
                                prefixIcon: Icon(Icons.qr_code_2),
                              ),
                              onFieldSubmitted: (_) => _lookupAsset(),
                            ),
                            if (assetLookup.hasError) ...[
                              const SizedBox(height: AppSpacing.md),
                              Notice(
                                tone: StatusTone.danger,
                                message: errorMessageFor(
                                  assetLookup.error!,
                                  fallback: 'Couldn\'t find that asset.',
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.md),
                            SubmitButton(
                              label: 'Find asset',
                              busyLabel: 'Looking up…',
                              icon: Icons.search,
                              busy: assetLookup.isLoading,
                              onPressed: _lookupAsset,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            OutlinedButton.icon(
                              onPressed: assetLookup.isLoading
                                  ? null
                                  : _scanAsset,
                              icon: const Icon(Icons.qr_code_scanner),
                              label: const Text('Scan QR code'),
                            ),
                          ],
                        )
                      : EntityHeader(
                          icon: Icons.check_rounded,
                          iconTone: StatusTone.success,
                          title: asset.name,
                          subtitle: asset.assetCode,
                          trailing: TextButton(
                            onPressed: submitState.isLoading
                                ? null
                                : () {
                                    ref
                                        .read(
                                          workflowAssetLookupControllerProvider
                                              .notifier,
                                        )
                                        .reset();
                                    _codeController.clear();
                                  },
                            child: const Text('Change'),
                          ),
                        ),
                ),
              ),
              if (asset != null) ...[
                const SizedBox(height: AppSpacing.xl),
                const _Step(
                  number: 2,
                  title: 'What should the agent evaluate?',
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: TextFormField(
                      controller: _objectiveController,
                      enabled: !submitState.isLoading,
                      minLines: 3,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Objective',
                        hintText: 'e.g. Recommend repair, replace or dispose.',
                        alignLabelWithHint: true,
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'State what the agent should evaluate'
                          : null,
                    ),
                  ),
                ),
                if (submitState.hasError) ...[
                  const SizedBox(height: AppSpacing.md),
                  Notice(
                    tone: StatusTone.danger,
                    message: errorMessageFor(
                      submitState.error!,
                      fallback: 'Couldn\'t start this evaluation. Try again.',
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                SubmitButton(
                  label: 'Request Evaluation',
                  busyLabel: 'Starting…',
                  icon: Icons.auto_awesome_outlined,
                  busy: submitState.isLoading,
                  onPressed: () => _submit(asset),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title});

  final int number;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: scheme.primary,
            child: Text(
              '$number',
              style: context.text.labelSmall?.copyWith(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(title, style: context.text.titleSmall),
        ],
      ),
    );
  }
}
