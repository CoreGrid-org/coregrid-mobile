import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';
import 'surfaces.dart';

/// Optional photo attachment used by fault reports and discrepancies: an
/// empty state with Camera / Gallery buttons, or the preview with a remove
/// action. The caller owns picking and the IF-11 ≤1 MB compression.
class PhotoEvidenceCard extends StatelessWidget {
  const PhotoEvidenceCard({
    super.key,
    required this.photoBytes,
    required this.compressing,
    required this.disabled,
    required this.onPick,
    required this.onRemove,
  });

  final Uint8List? photoBytes;
  final bool compressing;
  final bool disabled;
  final ValueChanged<ImageSource> onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (photoBytes != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    child: Image.memory(
                      photoBytes!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (onRemove != null)
                    Positioned(
                      top: AppSpacing.sm,
                      right: AppSpacing.sm,
                      child: IconButton.filledTonal(
                        tooltip: 'Remove photo',
                        onPressed: disabled ? null : onRemove,
                        icon: const Icon(Icons.close),
                      ),
                    ),
                ],
              )
            else
              Column(
                children: [
                  const IconTile(Icons.add_a_photo_outlined, size: 48),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Optional — compressed to under 1 MB before upload.',
                    textAlign: TextAlign.center,
                    style: context.mutedSmall,
                  ),
                ],
              ),
            if (compressing) ...[
              const SizedBox(height: AppSpacing.md),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: disabled
                        ? null
                        : () => onPick(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined, size: 20),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: disabled
                        ? null
                        : () => onPick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 20),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
