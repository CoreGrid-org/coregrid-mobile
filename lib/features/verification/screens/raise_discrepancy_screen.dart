import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/media/photo_picker.dart';
import '../../../shared/widgets/photo_evidence_card.dart';
import '../../../shared/widgets/ui.dart';
import '../models/discrepancy.dart';
import '../verification_providers.dart';

/// Screen for raising a discrepancy manually with an optional photo.
class RaiseDiscrepancyScreen extends ConsumerStatefulWidget {
  const RaiseDiscrepancyScreen({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<RaiseDiscrepancyScreen> createState() =>
      _RaiseDiscrepancyScreenState();
}

class _RaiseDiscrepancyScreenState
    extends ConsumerState<RaiseDiscrepancyScreen> {
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Discrepancy raised.')));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(raiseDiscrepancyControllerProvider);
    final busy = submitState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Raise discrepancy')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: AppSpacing.pageInsets,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Flag something the automatic comparison can\'t catch. '
                'Describe it, and attach a photo if it helps.',
                style: context.mutedBody,
              ),
              const SectionHeader('Details'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<DiscrepancyType>(
                        initialValue: _type,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: [
                          for (final t in DiscrepancyType.values)
                            DropdownMenuItem(value: t, child: Text(t.label)),
                        ],
                        onChanged: busy
                            ? null
                            : (v) {
                                if (v != null) setState(() => _type = v);
                              },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _descriptionController,
                        enabled: !busy,
                        minLines: 4,
                        maxLines: 6,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'What did you observe?',
                          alignLabelWithHint: true,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Describe the discrepancy'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SectionHeader('Photo evidence'),
              PhotoEvidenceCard(
                photoBytes: _photoBytes,
                compressing: _compressing,
                disabled: busy || _compressing,
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
                    fallback: 'Couldn\'t raise this discrepancy. Try again.',
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              SubmitButton(
                label: 'Submit',
                busyLabel: 'Submitting…',
                icon: Icons.send_outlined,
                busy: busy,
                onPressed: _compressing ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
