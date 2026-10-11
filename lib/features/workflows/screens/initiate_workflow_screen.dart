import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/ui.dart';
import '../../scan/screens/scan_asset_screen.dart';
import '../models/workflow_asset_ref.dart';
import '../models/workflow_asset_type.dart';
import '../workflows_providers.dart';

/// What an evaluation targets: one asset, or every active asset of a type.
enum _Scope { asset, assetType }

/// Screen to initiate a new agent workflow for one asset (scanned or typed)
/// or for an asset type picked by category. Route: `/workflows/new`.
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
  var _scope = _Scope.asset;
  WorkflowAssetCategory? _category;
  WorkflowAssetType? _assetType;

  /// For a chosen asset: evaluate every active asset of its type instead.
  var _wholeType = false;

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
    setState(() => _wholeType = false);
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
            assetTypeId: scanned.assetTypeId,
            assetTypeName: scanned.assetTypeName,
          ),
        );
    setState(() => _wholeType = false);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final asset = ref.read(workflowAssetLookupControllerProvider).asData?.value;
    final workflow = await ref
        .read(initiateWorkflowControllerProvider.notifier)
        .submit(
          assetId: _scope == _Scope.asset && !_wholeType ? asset?.id : null,
          assetTypeId: switch (_scope) {
            _Scope.asset when _wholeType => asset?.assetTypeId,
            _Scope.asset => null,
            _Scope.assetType => _assetType?.id,
          },
          objective: _objectiveController.text,
        );

    if (workflow != null && mounted) {
      context.pushReplacement('/workflows/${workflow.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final assetLookup = ref.watch(workflowAssetLookupControllerProvider);
    final submitState = ref.watch(initiateWorkflowControllerProvider);
    final asset = assetLookup.asData?.value;
    final hasTarget = switch (_scope) {
      _Scope.asset => asset != null,
      _Scope.assetType => _assetType != null,
    };

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
                'The CoreGrid agent reviews asset history and recommends '
                'what to do next — for example repair, replace or dispose.',
                style: context.mutedBody,
              ),
              const SizedBox(height: AppSpacing.xl),
              const _Step(number: 1, title: 'Choose what to evaluate'),
              SegmentedButton<_Scope>(
                segments: const [
                  ButtonSegment(
                    value: _Scope.asset,
                    icon: Icon(Icons.qr_code_scanner),
                    label: Text('One asset'),
                  ),
                  ButtonSegment(
                    value: _Scope.assetType,
                    icon: Icon(Icons.category_outlined),
                    label: Text('Asset type'),
                  ),
                ],
                selected: {_scope},
                showSelectedIcon: false,
                onSelectionChanged: submitState.isLoading
                    ? null
                    : (selection) => setState(() => _scope = selection.first),
              ),
              const SizedBox(height: AppSpacing.md),
              ClayCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: _scope == _Scope.assetType
                      ? _AssetTypePicker(
                          category: _category,
                          assetType: _assetType,
                          enabled: !submitState.isLoading,
                          onCategoryChanged: (category) => setState(() {
                            _category = category;
                            _assetType = null;
                          }),
                          onAssetTypeChanged: (type) =>
                              setState(() => _assetType = type),
                        )
                      : asset == null
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
                      : _ChosenAsset(
                          asset: asset,
                          wholeType: _wholeType,
                          enabled: !submitState.isLoading,
                          onWholeTypeChanged: (value) =>
                              setState(() => _wholeType = value),
                          change: TextButton(
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
              if (hasTarget) ...[
                const SizedBox(height: AppSpacing.xl),
                const _Step(
                  number: 2,
                  title: 'What should the agent evaluate?',
                ),
                ClayCard(
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
                  onPressed: _submit,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The asset found by code or scan, with its type and category resolved, and
/// the choice to evaluate just this asset or every active asset of its type.
class _ChosenAsset extends ConsumerWidget {
  const _ChosenAsset({
    required this.asset,
    required this.wholeType,
    required this.enabled,
    required this.onWholeTypeChanged,
    required this.change,
  });

  final WorkflowAssetRef asset;
  final bool wholeType;
  final bool enabled;
  final ValueChanged<bool> onWholeTypeChanged;
  final Widget change;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final header = EntityHeader(
      icon: Icons.check_rounded,
      iconTone: StatusTone.success,
      title: asset.name,
      subtitle: asset.assetCode,
      trailing: change,
    );
    // Without a type id there's nothing to widen to — single asset only.
    if (asset.assetTypeId.isEmpty) return header;

    // The asset record names its type but not its category; the asset-type
    // list does. If that list can't load, the category is simply omitted.
    final type = ref
        .watch(workflowAssetTypesProvider)
        .asData
        ?.value
        .where((t) => t.id == asset.assetTypeId)
        .firstOrNull;
    final typeName = type?.name ?? asset.assetTypeName;
    final category = type?.categoryName ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: AppSpacing.sm),
        InfoRow(
          icon: Icons.category_outlined,
          label: 'Asset type',
          value: typeName,
        ),
        if (category.isNotEmpty)
          InfoRow(
            icon: Icons.folder_outlined,
            label: 'Category',
            value: category,
          ),
        const Divider(),
        const SizedBox(height: AppSpacing.sm),
        Text('Evaluate', style: context.text.titleSmall),
        RadioGroup<bool>(
          groupValue: wholeType,
          onChanged: (value) {
            if (enabled && value != null) onWholeTypeChanged(value);
          },
          child: Column(
            children: [
              RadioListTile<bool>(
                value: false,
                enabled: enabled,
                contentPadding: EdgeInsets.zero,
                title: const Text('Just this asset'),
                subtitle: Text('Recommend an action for ${asset.assetCode}.'),
              ),
              RadioListTile<bool>(
                value: true,
                enabled: enabled,
                contentPadding: EdgeInsets.zero,
                title: Text('All $typeName assets'),
                subtitle: Text(
                  'Every active $typeName'
                  '${category.isEmpty ? '' : ' in $category'}, '
                  'evaluated together as a fleet.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Category → asset type cascade for a fleet evaluation. Categories come
/// from the asset types themselves, so only categories with a type appear.
class _AssetTypePicker extends ConsumerWidget {
  const _AssetTypePicker({
    required this.category,
    required this.assetType,
    required this.enabled,
    required this.onCategoryChanged,
    required this.onAssetTypeChanged,
  });

  final WorkflowAssetCategory? category;
  final WorkflowAssetType? assetType;
  final bool enabled;
  final ValueChanged<WorkflowAssetCategory?> onCategoryChanged;
  final ValueChanged<WorkflowAssetType?> onAssetTypeChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final types = ref.watch(workflowAssetTypesProvider);

    return switch (types) {
      AsyncData(:final value) when value.isEmpty => const Notice(
        icon: Icons.category_outlined,
        message:
            'No asset types are set up for your organisation yet. '
            'Evaluate a single asset instead.',
      ),
      AsyncData(:final value) => _buildPickers(context, value),
      AsyncError(:final error) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Notice(
            tone: StatusTone.danger,
            message: errorMessageFor(
              error,
              fallback: 'Couldn\'t load asset types.',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(workflowAssetTypesProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
      _ => const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      ),
    };
  }

  Widget _buildPickers(BuildContext context, List<WorkflowAssetType> types) {
    final categories = categoriesOf(types);
    final typesInCategory = category == null
        ? const <WorkflowAssetType>[]
        : types.where((type) => type.categoryId == category!.id).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<WorkflowAssetCategory>(
          isExpanded: true,
          initialValue: category,
          decoration: const InputDecoration(
            labelText: 'Category',
            prefixIcon: Icon(Icons.folder_outlined),
          ),
          items: [
            for (final c in categories)
              DropdownMenuItem(value: c, child: Text(c.name)),
          ],
          onChanged: enabled ? onCategoryChanged : null,
          validator: (value) => value == null ? 'Select a category' : null,
        ),
        const SizedBox(height: AppSpacing.md),
        if (category == null)
          const InputDecorator(
            decoration: InputDecoration(
              labelText: 'Asset type',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            child: Text('Select a category first'),
          )
        else
          DropdownButtonFormField<WorkflowAssetType>(
            // Rebuilt per category so the previous category's type can't
            // linger as the selected value.
            key: ValueKey(category!.id),
            isExpanded: true,
            initialValue: assetType,
            decoration: const InputDecoration(
              labelText: 'Asset type',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: [
              for (final type in typesInCategory)
                DropdownMenuItem(value: type, child: Text(type.name)),
            ],
            onChanged: enabled ? onAssetTypeChanged : null,
            validator: (value) => value == null ? 'Select an asset type' : null,
          ),
        if (assetType != null) ...[
          const SizedBox(height: AppSpacing.md),
          Notice(
            icon: Icons.inventory_2_outlined,
            message:
                'Evaluates every active ${assetType!.name} asset together '
                'and recommends an action for each.',
          ),
        ],
      ],
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
