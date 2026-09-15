import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/api/api_exception.dart';
import '../models/discrepancy.dart';
import '../verification_providers.dart';

/// FR-061 — raise a discrepancy manually, with an optional photo compressed
/// client-side to ≤1MB before upload (IF-11, same rule the SRS states for
/// fault-report photos — applied here for consistency). Route:
/// `/verification/:taskId/discrepancy`.
class RaiseDiscrepancyScreen extends ConsumerStatefulWidget {
  const RaiseDiscrepancyScreen({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<RaiseDiscrepancyScreen> createState() =>
      _RaiseDiscrepancyScreenState();
}

class _RaiseDiscrepancyScreenState
    extends ConsumerState<RaiseDiscrepancyScreen> {
  static const _maxPhotoBytes = 1024 * 1024; // IF-11: ≤1MB

  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  DiscrepancyType _type = DiscrepancyType.other;
  Uint8List? _photoBytes;
  String? _photoFileName;
  bool _compressing = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
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

  /// Compresses by stepping quality down until the result is ≤1MB or quality
  /// bottoms out — same approach the SRS mandates for fault-report photos.
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
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final success = await ref
        .read(raiseDiscrepancyControllerProvider.notifier)
        .submit(
          taskId: widget.taskId,
          type: _type,
          description: _descriptionController.text,
          photoBytes: _photoBytes,
          photoFileName: _photoFileName,
        );

    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Discrepancy raised.')));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(raiseDiscrepancyControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Raise Discrepancy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Flag something the automatic comparison cannot catch. '
                'Describe it, and attach a photo if it helps.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<DiscrepancyType>(
                initialValue: _type,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final type in DiscrepancyType.values)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: submitState.isLoading
                    ? null
                    : (value) {
                        if (value != null) setState(() => _type = value);
                      },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                enabled: !submitState.isLoading,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Describe the discrepancy'
                    : null,
              ),
              const SizedBox(height: 12),
              if (_photoBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    _photoBytes!,
                    height: 160,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: (submitState.isLoading || _compressing)
                        ? null
                        : () => _pickPhoto(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Take Photo'),
                  ),
                  OutlinedButton.icon(
                    onPressed: (submitState.isLoading || _compressing)
                        ? null
                        : () => _pickPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Choose Photo'),
                  ),
                ],
              ),
              if (_compressing) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: (submitState.isLoading || _compressing)
                    ? null
                    : _submit,
                icon: submitState.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(submitState.isLoading ? 'Submitting…' : 'Submit'),
              ),
              if (submitState.hasError) ...[
                const SizedBox(height: 12),
                Text(
                  submitState.error is ApiException
                      ? (submitState.error as ApiException).message
                      : 'Couldn\'t raise this discrepancy. Try again.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
