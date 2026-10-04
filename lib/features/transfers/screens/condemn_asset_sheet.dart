import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/api/api_exception.dart';
import '../../../shared/utils/image_compression.dart';
import '../../../shared/widgets/ui.dart';
import '../../assets/models/asset/asset_condition.dart';
import '../../assets/models/asset/asset_detail.dart';
import '../../assets/widgets/asset/condition_update_sheet.dart';
import '../models/condemn_asset_request.dart';
import '../transfers_api.dart';
import '../transfers_providers.dart';

/// Bottom sheet for condemning an unserviceable asset (FR-049).
///
/// Precondition: Requires a recorded condition of Poor or Unserviceable.
/// If condition is ineligible, guides the user to update the condition first.
class CondemnAssetSheet extends ConsumerStatefulWidget {
  const CondemnAssetSheet({super.key, required this.asset});

  final AssetDetail asset;

  static Future<bool?> show(
    BuildContext context, {
    required AssetDetail asset,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CondemnAssetSheet(asset: asset),
    );
  }

  @override
  ConsumerState<CondemnAssetSheet> createState() => _CondemnAssetSheetState();
}

class _CondemnAssetSheetState extends ConsumerState<CondemnAssetSheet> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _evidenceUrlController = TextEditingController();

  Uint8List? _photoBytes;
  String? _photoFileName;
  bool _compressing = false;
  bool _isUploadingPhoto = false;
  String? _errorMessage;

  @override
  void dispose() {
    _reasonController.dispose();
    _evidenceUrlController.dispose();
    super.dispose();
  }

  bool get _isConditionEligible {
    final c = widget.asset.condition;
    return c == AssetCondition.poor || c == AssetCondition.unserviceable;
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 90,
    );
    if (picked == null) return;

    setState(() => _compressing = true);
    try {
      final compressed = await compressImageUnderLimit(picked.path);
      setState(() {
        _photoBytes = compressed;
        _photoFileName = picked.name;
      });
    } finally {
      if (mounted) setState(() => _compressing = false);
    }
  }

  void _removePhoto() {
    setState(() {
      _photoBytes = null;
      _photoFileName = null;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _errorMessage = null;
    });

    String? photoUrl;
    if (_photoBytes != null && _photoFileName != null) {
      setState(() => _isUploadingPhoto = true);
      try {
        photoUrl = await ref
            .read(transfersApiProvider)
            .uploadEvidencePhoto(
              bytes: _photoBytes!,
              fileName: _photoFileName!,
            );
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() {
          _isUploadingPhoto = false;
          _errorMessage = e.message;
        });
        return;
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isUploadingPhoto = false;
          _errorMessage = 'Could not upload photo evidence. Please try again.';
        });
        return;
      } finally {
        if (mounted) setState(() => _isUploadingPhoto = false);
      }
    }

    final manualUrl = _evidenceUrlController.text.trim();
    final effectiveEvidenceUrl =
        photoUrl ?? (manualUrl.isNotEmpty ? manualUrl : null);

    final request = CondemnAssetRequest(
      reason: _reasonController.text.trim(),
      evidenceUrl: effectiveEvidenceUrl,
    );

    final success = await ref
        .read(condemnAssetControllerProvider.notifier)
        .submit(assetId: widget.asset.id, request: request);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      final error = ref.read(condemnAssetControllerProvider).error;
      setState(() {
        _errorMessage = error is ApiException
            ? error.message
            : 'Could not condemn asset. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColors = AppColors.of(context);
    final isSubmitting =
        ref.watch(condemnAssetControllerProvider).isLoading ||
        _isUploadingPhoto;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColors.dangerContainer,
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                    ),
                    child: Icon(
                      Icons.gavel_outlined,
                      color: statusColors.danger,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Condemn Asset',
                      style: context.text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!_isConditionEligible) ...[
                _buildIneligibleGuard(context),
              ] else ...[
                _buildCondemnForm(context, isSubmitting),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIneligibleGuard(BuildContext context) {
    final statusColors = AppColors.of(context);
    final conditionLabel =
        widget.asset.condition?.label ?? widget.asset.conditionRaw;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: statusColors.warningContainer,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: statusColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: statusColors.warning,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Condition Ineligible for Condemnation',
                  style: TextStyle(
                    color: context.colors.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Condemnation requires a recorded condition of Poor or Unserviceable (FR-049).\n\n'
            'Current condition: $conditionLabel\n'
            'Please update the asset\'s condition before proceeding with condemnation.',
            style: TextStyle(
              color: context.colors.onSurfaceVariant,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: () async {
                final updated = await ConditionUpdateSheet.show(
                  context,
                  assetId: widget.asset.id,
                  current: widget.asset.condition,
                );
                if (updated == true && context.mounted) {
                  Navigator.of(context).pop(true);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: context.colors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
              ),
              icon: const Icon(Icons.tune_rounded, size: 20),
              label: const Text(
                'Update Condition First',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildCondemnForm(BuildContext context, bool isSubmitting) {
    final statusColors = AppColors.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: statusColors.dangerContainer,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(
                color: statusColors.danger.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: statusColors.danger, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Asset ${widget.asset.assetCode} will be permanently marked as Condemned and taken out of service.',
                    style: TextStyle(
                      color: statusColors.danger,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _reasonController,
            enabled: !isSubmitting,
            maxLines: 4,
            maxLength: 1000,
            style: TextStyle(fontSize: 15, color: context.colors.onSurface),
            decoration: _inputDecoration(
              label: 'Reason for Condemnation *',
              hint: 'Explain why the asset cannot be repaired or economically restored...',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Explain why the asset can\'t be repaired or used.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          if (_photoBytes != null) ...[
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  child: Image.memory(
                    _photoBytes!,
                    height: 170,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    radius: 18,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: isSubmitting ? null : _removePhoto,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (isSubmitting || _compressing)
                      ? null
                      : () => _pickPhoto(ImageSource.camera),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.onSurface,
                    backgroundColor: context.colors.surfaceContainerLow,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: context.colors.outlineVariant),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                    ),
                  ),
                  icon: const Icon(Icons.camera_alt_outlined, size: 19),
                  label: const Text(
                    'Take Photo',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (isSubmitting || _compressing)
                      ? null
                      : () => _pickPhoto(ImageSource.gallery),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.onSurface,
                    backgroundColor: context.colors.surfaceContainerLow,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: context.colors.outlineVariant),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                    ),
                  ),
                  icon: const Icon(Icons.photo_library_outlined, size: 19),
                  label: const Text(
                    'Choose Photo',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
          if (_compressing) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 14),
          TextFormField(
            controller: _evidenceUrlController,
            enabled: !isSubmitting,
            style: TextStyle(fontSize: 15, color: context.colors.onSurface),
            decoration: _inputDecoration(
              label: 'Evidence URL (optional)',
              hint: 'https://... (link to inspection report or quote)',
            ),
            validator: (v) {
              if (v != null && v.trim().isNotEmpty) {
                final uri = Uri.tryParse(v.trim());
                if (uri == null ||
                    (!uri.isScheme('http') && !uri.isScheme('https'))) {
                  return 'Enter a valid URL starting with http:// or https://';
                }
              }
              return null;
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColors.dangerContainer,
                borderRadius: BorderRadius.circular(AppRadius.tile),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  color: statusColors.danger,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: isSubmitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: statusColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control),
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
                  : const Icon(Icons.gavel_outlined, size: 20),
              label: Text(
                isSubmitting ? 'Condemning asset...' : 'Condemn Asset',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({required String label, String? hint}) {
    final statusColors = AppColors.of(context);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(
        color: context.colors.onSurfaceVariant,
        fontSize: 14,
      ),
      filled: true,
      fillColor: context.colors.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: BorderSide(color: context.colors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: BorderSide(color: context.colors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: BorderSide(color: statusColors.danger, width: 1.5),
      ),
    );
  }
}
