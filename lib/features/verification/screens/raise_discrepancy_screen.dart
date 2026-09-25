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

/// Screen for raising a discrepancy manually with an optional photo.
class RaiseDiscrepancyScreen extends ConsumerStatefulWidget {
  const RaiseDiscrepancyScreen({super.key, required this.taskId});

  final String taskId;

  static const Color orange = Color(0xFFFF5A00);
  static const Color lightOrange = Color(0xFFFFF0E8);
  static const Color cardFill = Color(0xFFFFFBF9);
  static const Color cardBorder = Color(0xFFFFE2D3);
  static const Color darkText = Color(0xFF202625);
  static const Color secondaryText = Color(0xFF59635F);

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Discrepancy raised.'),
          duration: Duration(seconds: 5),
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(raiseDiscrepancyControllerProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: const Text(
          'Raise Discrepancy',
          style: TextStyle(
            color: RaiseDiscrepancyScreen.darkText,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(
          color: RaiseDiscrepancyScreen.darkText,
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
              const _DiscrepancyHeader(),
              const SizedBox(height: 24),
              _DiscrepancyFormCard(
                type: _type,
                onTypeChanged: submitState.isLoading
                    ? null
                    : (val) {
                        if (val != null) setState(() => _type = val);
                      },
                descriptionController: _descriptionController,
                isLoading: submitState.isLoading,
                photoBytes: _photoBytes,
                compressing: _compressing,
                onPickPhoto: (source) => _pickPhoto(source),
                onSubmit: (submitState.isLoading || _compressing) ? null : _submit,
                isSubmitting: submitState.isLoading,
                errorMessage: submitState.hasError
                    ? (submitState.error is ApiException
                        ? (submitState.error as ApiException).message
                        : 'Couldn\'t raise this discrepancy. Try again.')
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscrepancyHeader extends StatelessWidget {
  const _DiscrepancyHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: RaiseDiscrepancyScreen.lightOrange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.report_problem_rounded,
                size: 32,
                color: RaiseDiscrepancyScreen.orange,
              ),
            ),
            const SizedBox(width: 18),
            const Expanded(
              child: Text(
                'Raise Discrepancy',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: RaiseDiscrepancyScreen.darkText,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Flag something the automatic comparison cannot catch. '
          'Describe it, and attach a photo if it helps.',
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: RaiseDiscrepancyScreen.secondaryText,
          ),
        ),
      ],
    );
  }
}

class _DiscrepancyFormCard extends StatelessWidget {
  const _DiscrepancyFormCard({
    required this.type,
    required this.onTypeChanged,
    required this.descriptionController,
    required this.isLoading,
    required this.photoBytes,
    required this.compressing,
    required this.onPickPhoto,
    required this.onSubmit,
    required this.isSubmitting,
    this.errorMessage,
  });

  final DiscrepancyType type;
  final ValueChanged<DiscrepancyType?>? onTypeChanged;
  final TextEditingController descriptionController;
  final bool isLoading;
  final Uint8List? photoBytes;
  final bool compressing;
  final ValueChanged<ImageSource> onPickPhoto;
  final VoidCallback? onSubmit;
  final bool isSubmitting;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RaiseDiscrepancyScreen.cardFill,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: RaiseDiscrepancyScreen.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<DiscrepancyType>(
            initialValue: type,
            isExpanded: true,
            style: const TextStyle(
              fontSize: 15,
              color: RaiseDiscrepancyScreen.darkText,
            ),
            decoration: _inputDecoration('Type'),
            items: [
              for (final t in DiscrepancyType.values)
                DropdownMenuItem(value: t, child: Text(t.label)),
            ],
            onChanged: onTypeChanged,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: descriptionController,
            enabled: !isLoading,
            maxLines: 4,
            style: const TextStyle(
              fontSize: 15,
              color: RaiseDiscrepancyScreen.darkText,
            ),
            decoration: _inputDecoration('Description'),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Describe the discrepancy'
                : null,
          ),
          const SizedBox(height: 14),
          if (photoBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                photoBytes!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
          ],
          _PhotoActionButtons(
            disabled: isLoading || compressing,
            onPickPhoto: onPickPhoto,
          ),
          if (compressing) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(
              color: RaiseDiscrepancyScreen.orange,
            ),
          ],
          const SizedBox(height: 20),
          _SubmitButton(
            onSubmit: onSubmit,
            isSubmitting: isSubmitting,
          ),
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

class _PhotoActionButtons extends StatelessWidget {
  const _PhotoActionButtons({
    required this.disabled,
    required this.onPickPhoto,
  });

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
              foregroundColor: RaiseDiscrepancyScreen.orange,
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              side: const BorderSide(color: Color(0xFFE5E7E6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.camera_alt_outlined, size: 20),
            label: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: disabled ? null : () => onPickPhoto(ImageSource.gallery),
            style: OutlinedButton.styleFrom(
              foregroundColor: RaiseDiscrepancyScreen.orange,
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              side: const BorderSide(color: Color(0xFFE5E7E6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.photo_library_outlined, size: 20),
            label: const Text('Choose Photo', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.onSubmit,
    required this.isSubmitting,
  });

  final VoidCallback? onSubmit;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: FilledButton.icon(
        onPressed: onSubmit,
        style: FilledButton.styleFrom(
          backgroundColor: RaiseDiscrepancyScreen.orange,
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
          isSubmitting ? 'Submitting…' : 'Submit',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(
      color: RaiseDiscrepancyScreen.secondaryText,
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
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(
        color: RaiseDiscrepancyScreen.orange,
        width: 1.5,
      ),
    ),
  );
}
