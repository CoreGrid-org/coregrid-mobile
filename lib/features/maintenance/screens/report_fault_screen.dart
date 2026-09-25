import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../assets/models/asset/asset_condition.dart';
import '../../assets/models/asset/asset_detail.dart';
import '../../../shared/api/api_exception.dart';
import '../maintenance_providers.dart';

/// FR-080 — staff member or inventory officer reports a fault against an asset,
/// with observed condition and optional compressed photo evidence (IF-11).
/// Designed using CoreGrid's orange brand design system.
class ReportFaultScreen extends ConsumerStatefulWidget {
  const ReportFaultScreen({super.key, this.assetId, this.assetCode});

  /// Pre-filled when navigating from an asset detail; null when arriving directly
  /// from the dashboard without a pre-selected asset.
  final String? assetId;
  final String? assetCode;

  static const Color orange = Color(0xFFFF5A00);
  static const Color lightOrange = Color(0xFFFFF0E8);
  static const Color cardFill = Color(0xFFFFFBF9);
  static const Color cardBorder = Color(0xFFFFE2D3);
  static const Color darkText = Color(0xFF202625);
  static const Color secondaryText = Color(0xFF59635F);

  @override
  ConsumerState<ReportFaultScreen> createState() => _ReportFaultScreenState();
}

class _ReportFaultScreenState extends ConsumerState<ReportFaultScreen> {
  static const _maxPhotoBytes = 1024 * 1024; // IF-11: ≤1 MB

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

  void _clearSelectedAsset() {
    if (widget.assetId != null) return; // Locked if passed via route
    setState(() {
      _selectedAssetId = null;
      _selectedAssetCode = null;
      _selectedAssetName = null;
      _selectedAssetDepartment = null;
    });
  }

  Future<void> _openAssetPicker() async {
    final selected = await showModalBottomSheet<AssetDetail>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _AssetPickerSheet(),
    );
    if (selected != null) {
      _onAssetSelected(selected);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 90,
    );
    if (picked == null) return;

    setState(() => _compressing = true);
    try {
      final compressed = await _compressUnderLimit(picked.path);
      setState(() {
        _photoBytes = compressed;
        _photoFileName = picked.name;
      });
    } finally {
      if (mounted) setState(() => _compressing = false);
    }
  }

  Future<Uint8List> _compressUnderLimit(String path) async {
    var quality = 85;
    Uint8List result = await FlutterImageCompress.compressWithFile(
          path,
          quality: quality,
          minWidth: 1280,
          minHeight: 1280,
        ) ??
        await File(path).readAsBytes();

    while (result.length > _maxPhotoBytes && quality > 20) {
      quality -= 15;
      result = await FlutterImageCompress.compressWithFile(
            path,
            quality: quality,
            minWidth: 1280,
            minHeight: 1280,
          ) ??
          result;
    }
    return result;
  }

  Future<void> _submit() async {
    if (_selectedAssetId == null || _selectedAssetId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an asset first.'),
          backgroundColor: Colors.redAccent,
        ),
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
        const SnackBar(
          content: Text('Fault report submitted successfully.'),
          duration: Duration(seconds: 4),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(reportFaultControllerProvider);
    final isLoading = submitState.isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: const Text(
          'Report Fault',
          style: TextStyle(
            color: ReportFaultScreen.darkText,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(
          color: ReportFaultScreen.darkText,
        ),
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _FaultHeader(),
              const SizedBox(height: 24),
              _FaultFormCard(
                selectedAssetId: _selectedAssetId,
                selectedAssetCode: _selectedAssetCode,
                selectedAssetName: _selectedAssetName,
                selectedAssetDepartment: _selectedAssetDepartment,
                assetCodeLocked: widget.assetId != null,
                onPickAsset: isLoading ? null : _openAssetPicker,
                onClearAsset: isLoading ? null : _clearSelectedAsset,
                descriptionController: _descriptionController,
                observedCondition: _observedCondition,
                onConditionChanged: isLoading
                    ? null
                    : (val) {
                        if (val != null) {
                          setState(() => _observedCondition = val);
                        }
                      },
                isLoading: isLoading,
                photoBytes: _photoBytes,
                compressing: _compressing,
                onPickPhoto: _pickPhoto,
                onRemovePhoto: isLoading
                    ? null
                    : () => setState(() {
                          _photoBytes = null;
                          _photoFileName = null;
                        }),
                onSubmit: (isLoading || _compressing) ? null : _submit,
                isSubmitting: isLoading,
                errorMessage: submitState.hasError
                    ? (submitState.error is ApiException
                        ? (submitState.error as ApiException).message
                        : 'Couldn\'t submit this report. Please try again.')
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _FaultHeader extends StatelessWidget {
  const _FaultHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: ReportFaultScreen.lightOrange,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.build_circle_outlined,
                size: 30,
                color: ReportFaultScreen.orange,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report Asset Fault',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: ReportFaultScreen.darkText,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Department Assets',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: ReportFaultScreen.orange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'Select an asset from your department to report a defect or damage to the maintenance team.',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: ReportFaultScreen.secondaryText,
          ),
        ),
      ],
    );
  }
}

// ── Form card ────────────────────────────────────────────────────────────────

class _FaultFormCard extends StatelessWidget {
  const _FaultFormCard({
    required this.selectedAssetId,
    required this.selectedAssetCode,
    required this.selectedAssetName,
    required this.selectedAssetDepartment,
    required this.assetCodeLocked,
    required this.onPickAsset,
    required this.onClearAsset,
    required this.descriptionController,
    required this.observedCondition,
    required this.onConditionChanged,
    required this.isLoading,
    required this.photoBytes,
    required this.compressing,
    required this.onPickPhoto,
    required this.onRemovePhoto,
    required this.onSubmit,
    required this.isSubmitting,
    this.errorMessage,
  });

  final String? selectedAssetId;
  final String? selectedAssetCode;
  final String? selectedAssetName;
  final String? selectedAssetDepartment;
  final bool assetCodeLocked;
  final VoidCallback? onPickAsset;
  final VoidCallback? onClearAsset;
  final TextEditingController descriptionController;
  final AssetCondition observedCondition;
  final ValueChanged<AssetCondition?>? onConditionChanged;
  final bool isLoading;
  final Uint8List? photoBytes;
  final bool compressing;
  final ValueChanged<ImageSource> onPickPhoto;
  final VoidCallback? onRemovePhoto;
  final VoidCallback? onSubmit;
  final bool isSubmitting;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ReportFaultScreen.cardFill,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ReportFaultScreen.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section: Asset Selection
          const Text(
            'Target Asset',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ReportFaultScreen.secondaryText,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          if (selectedAssetId != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ReportFaultScreen.orange.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: ReportFaultScreen.lightOrange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: ReportFaultScreen.orange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedAssetCode ?? 'Asset Code',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: ReportFaultScreen.darkText,
                          ),
                        ),
                        if (selectedAssetName != null &&
                            selectedAssetName!.isNotEmpty)
                          Text(
                            selectedAssetName!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: ReportFaultScreen.secondaryText,
                            ),
                          ),
                        if (selectedAssetDepartment != null &&
                            selectedAssetDepartment!.isNotEmpty)
                          Text(
                            selectedAssetDepartment!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: ReportFaultScreen.orange,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!assetCodeLocked && !isLoading)
                    IconButton(
                      icon: const Icon(Icons.swap_horiz, color: ReportFaultScreen.orange),
                      tooltip: 'Change Asset',
                      onPressed: onPickAsset,
                    ),
                ],
              ),
            ),
          ] else ...[
            InkWell(
              onTap: onPickAsset,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7E6)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.search,
                      color: ReportFaultScreen.orange,
                      size: 22,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Select Asset from Department…',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: ReportFaultScreen.secondaryText,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: ReportFaultScreen.secondaryText,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),

          // Section: Observed Condition
          const Text(
            'Observed Condition',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ReportFaultScreen.secondaryText,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<AssetCondition>(
            initialValue: observedCondition,
            isExpanded: true,
            style: const TextStyle(
              fontSize: 15,
              color: ReportFaultScreen.darkText,
            ),
            decoration: _inputDecoration('Condition'),
            items: [
              for (final c in AssetCondition.values)
                DropdownMenuItem(value: c, child: Text(c.label)),
            ],
            onChanged: onConditionChanged,
          ),
          const SizedBox(height: 18),

          // Section: Description
          const Text(
            'Fault Description',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ReportFaultScreen.secondaryText,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: descriptionController,
            enabled: !isLoading,
            maxLines: 4,
            style: const TextStyle(
              fontSize: 15,
              color: ReportFaultScreen.darkText,
            ),
            decoration: _inputDecoration('Describe the issue or defect…'),
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'Please describe the fault' : null,
          ),
          const SizedBox(height: 18),

          // Section: Photo Evidence
          const Text(
            'Photo Evidence (Optional)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ReportFaultScreen.secondaryText,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          if (photoBytes != null) ...[
            Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    photoBytes!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                if (!isLoading && onRemovePhoto != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      radius: 16,
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 16, color: Colors.white),
                        onPressed: onRemovePhoto,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          _PhotoButtons(
            disabled: isLoading || compressing,
            onPickPhoto: onPickPhoto,
          ),
          if (compressing) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(
              color: ReportFaultScreen.orange,
            ),
          ],
          const SizedBox(height: 24),
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

// ── Asset Picker Sheet ────────────────────────────────────────────────────────

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

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select Department Asset',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: ReportFaultScreen.darkText,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by code or name…',
                prefixIcon: const Icon(Icons.search, color: ReportFaultScreen.orange),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE5E7E6)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE5E7E6)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: ReportFaultScreen.orange),
                ),
              ),
              onChanged: (val) {
                setState(() => _searchTerm = val.trim());
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: searchAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: ReportFaultScreen.orange),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Could not load department assets: $err',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),
              data: (assets) {
                if (assets.isEmpty) {
                  return const Center(
                    child: Text(
                      'No accessible assets found in your department.',
                      style: TextStyle(color: ReportFaultScreen.secondaryText),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: assets.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 64),
                  itemBuilder: (context, index) {
                    final asset = assets[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: ReportFaultScreen.lightOrange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: ReportFaultScreen.orange,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        asset.assetCode,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: ReportFaultScreen.darkText,
                        ),
                      ),
                      subtitle: Text(
                        '${asset.name} · ${asset.departmentName}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: ReportFaultScreen.secondaryText,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                      onTap: () => Navigator.pop(context, asset),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ── Photo buttons ─────────────────────────────────────────────────────────────

class _PhotoButtons extends StatelessWidget {
  const _PhotoButtons({required this.disabled, required this.onPickPhoto});

  final bool disabled;
  final ValueChanged<ImageSource> onPickPhoto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: disabled ? null : () => onPickPhoto(ImageSource.camera),
            style: OutlinedButton.styleFrom(
              foregroundColor: ReportFaultScreen.orange,
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              side: const BorderSide(color: Color(0xFFE5E7E6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.camera_alt_outlined, size: 20),
            label: const Text(
              'Camera',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: disabled ? null : () => onPickPhoto(ImageSource.gallery),
            style: OutlinedButton.styleFrom(
              foregroundColor: ReportFaultScreen.orange,
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              side: const BorderSide(color: Color(0xFFE5E7E6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.photo_library_outlined, size: 20),
            label: const Text(
              'Gallery',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Submit button ─────────────────────────────────────────────────────────────

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
          backgroundColor: ReportFaultScreen.orange,
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
            : const Icon(Icons.send_outlined, size: 20),
        label: Text(
          isSubmitting ? 'Submitting…' : 'Submit Fault Report',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ── Input decoration helper ────────────────────────────────────────────────────

InputDecoration _inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(
      color: ReportFaultScreen.secondaryText,
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
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFE5E7E6)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(
        color: ReportFaultScreen.orange,
        width: 1.5,
      ),
    ),
  );
}
