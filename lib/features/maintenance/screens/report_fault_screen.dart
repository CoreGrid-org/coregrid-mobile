import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../assets/models/asset/asset_condition.dart';
import '../../assets/models/asset/asset_detail.dart';
import '../../../shared/media/photo_picker.dart';
import '../../../shared/widgets/photo_evidence_card.dart';
import '../../../shared/widgets/ui.dart';
import '../maintenance_providers.dart';

/// Screen for reporting a fault against an asset, with observed condition and optional photo.
class ReportFaultScreen extends ConsumerStatefulWidget {
  const ReportFaultScreen({super.key, this.assetId, this.assetCode});

  /// Pre-filled when navigating from an asset detail; null when arriving directly
  /// from the dashboard without a pre-selected asset.
  final String? assetId;
  final String? assetCode;

  @override
  ConsumerState<ReportFaultScreen> createState() => _ReportFaultScreenState();
}

class _ReportFaultScreenState extends ConsumerState<ReportFaultScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  String? _selectedAssetId;
  String? _selectedAssetCode;
  String? _selectedAssetName;
  String? _selectedAssetDepartment;

  AssetCondition _observedCondition = AssetCondition.fair;
  Uint8List? _photoBytes;
  String? _photoFileName;
  bool _compressing = false;

  @override
  void initState() {
    super.initState();
    if (widget.assetId != null) {
      _selectedAssetId = widget.assetId;
      _selectedAssetCode = widget.assetCode ?? widget.assetId;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _onAssetSelected(AssetDetail asset) {
    setState(() {
      _selectedAssetId = asset.id;
      _selectedAssetCode = asset.assetCode;
      _selectedAssetName = asset.name;
      _selectedAssetDepartment = asset.departmentName;
    });
  }

  Future<void> _openAssetPicker() async {
    final selected = await showModalBottomSheet<AssetDetail>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _AssetPickerSheet(),
    );
    if (selected != null) {
      _onAssetSelected(selected);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    setState(() => _compressing = true);
    try {
      final photo = await pickCompressedPhoto(source);
      if (photo != null && mounted) {
        setState(() {
          _photoBytes = photo.bytes;
          _photoFileName = photo.fileName;
        });
      }
    } finally {
      if (mounted) setState(() => _compressing = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedAssetId == null || _selectedAssetId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an asset first.')),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final success = await ref
        .read(reportFaultControllerProvider.notifier)
        .submit(
          assetId: _selectedAssetId!,
          assetCode: _selectedAssetCode,
          description: _descriptionController.text,
          observedCondition: _observedCondition.apiValue,
          photoBytes: _photoBytes?.toList(),
          photoFileName: _photoFileName,
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fault report submitted successfully.')),
      );
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(reportFaultControllerProvider);
    final isLoading = submitState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Report Asset Fault')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: AppSpacing.pageInsets,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tell the maintenance team what\'s wrong. Add a photo if it '
                'helps them understand the problem.',
                style: context.mutedBody,
              ),
              const SectionHeader('Asset'),
              _AssetField(
                assetCode: _selectedAssetCode,
                assetName: _selectedAssetName,
                department: _selectedAssetDepartment,
                locked: widget.assetId != null,
                onPick: isLoading ? null : _openAssetPicker,
              ),
              const SectionHeader('Observed Condition'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final c in AssetCondition.values)
                        ChoiceChip(
                          label: Text(c.label),
                          selected: _observedCondition == c,
                          onSelected: isLoading
                              ? null
                              : (_) => setState(() => _observedCondition = c),
                        ),
                    ],
                  ),
                ),
              ),
              const SectionHeader('Fault Description'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: TextFormField(
                    controller: _descriptionController,
                    enabled: !isLoading,
                    minLines: 4,
                    maxLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Describe the issue or defect…',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Please describe the fault'
                        : null,
                  ),
                ),
              ),
              const SectionHeader('Photo Evidence'),
              PhotoEvidenceCard(
                photoBytes: _photoBytes,
                compressing: _compressing,
                disabled: isLoading || _compressing,
                onPick: _pickPhoto,
                onRemove: () => setState(() {
                  _photoBytes = null;
                  _photoFileName = null;
                }),
              ),
              if (submitState.hasError) ...[
                const SizedBox(height: AppSpacing.md),
                Notice(
                  tone: StatusTone.danger,
                  message: errorMessageFor(
                    submitState.error!,
                    fallback: 'Couldn\'t submit this report. Please try again.',
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              SubmitButton(
                label: 'Submit Fault Report',
                busyLabel: 'Submitting…',
                icon: Icons.send_outlined,
                busy: isLoading,
                onPressed: _compressing ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The chosen asset, or a prompt to choose one from the department list.
class _AssetField extends StatelessWidget {
  const _AssetField({
    required this.assetCode,
    required this.assetName,
    required this.department,
    required this.locked,
    required this.onPick,
  });

  final String? assetCode;
  final String? assetName;
  final String? department;
  final bool locked;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    if (assetCode == null) {
      return Card(
        child: RecordTile(
          icon: Icons.search,
          title: 'Select Asset from Department…',
          onTap: onPick,
        ),
      );
    }
    final details = [
      assetName,
      department,
    ].whereType<String>().where((s) => s.isNotEmpty).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: EntityHeader(
          icon: Icons.inventory_2_outlined,
          title: assetCode!,
          subtitle: details.join(' · '),
          trailing: locked
              ? null
              : TextButton(onPressed: onPick, child: const Text('Change')),
        ),
      ),
    );
  }
}

class _AssetPickerSheet extends ConsumerStatefulWidget {
  const _AssetPickerSheet();

  @override
  ConsumerState<_AssetPickerSheet> createState() => _AssetPickerSheetState();
}

class _AssetPickerSheetState extends ConsumerState<_AssetPickerSheet> {
  final _searchController = TextEditingController();
  String _searchTerm = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchAsync = ref.watch(faultAssetSearchProvider(_searchTerm));

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: Text(
              'Select Department Asset',
              style: context.text.titleLarge,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.md,
              AppSpacing.page,
              AppSpacing.md,
            ),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search by code or name…',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (val) => setState(() => _searchTerm = val.trim()),
            ),
          ),
          const Divider(),
          Expanded(
            child: switch (searchAsync) {
              AsyncData(:final value) when value.isEmpty => const MessageView(
                icon: Icons.inventory_2_outlined,
                title: 'No assets found',
                message: 'No accessible assets found in your department.',
              ),
              AsyncData(:final value) => ListView.separated(
                itemCount: value.length,
                separatorBuilder: (context, index) => const Divider(indent: 72),
                itemBuilder: (context, index) {
                  final asset = value[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.page,
                      vertical: AppSpacing.xs,
                    ),
                    leading: const IconTile(Icons.inventory_2_outlined),
                    title: Text(
                      asset.assetCode,
                      style: context.text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text('${asset.name} · ${asset.departmentName}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(context, asset),
                  );
                },
              ),
              AsyncError(:final error) => MessageView(
                icon: Icons.error_outline,
                tone: StatusTone.danger,
                title: 'Couldn\'t load department assets',
                message: errorMessageFor(error),
              ),
              _ => const LoadingView(),
            },
          ),
        ],
      ),
    );
  }
}
