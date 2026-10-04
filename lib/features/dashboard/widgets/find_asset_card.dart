import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/api/api_exception.dart';
import '../../../shared/widgets/ui.dart';
import '../../assets/assets_api.dart';

/// The dashboard's single entry point for getting to an asset — replaces the
/// separate "Scan Asset" / "Enter Code" / "Search Assets" tiles, which were
/// three doors to the same room.
///
///  - **Scan QR code** is the primary path (FR-024) and gets the most weight.
///  - The field underneath takes either an asset code or free text. A single
///    token is first tried as an exact code (`GET /api/assets/qr/{code}`,
///    the same call manual entry uses) and opens the asset directly; if no
///    asset has that code — or the input has spaces, so can't be a code — it
///    falls through to Search Assets with the text pre-filled.
///  - The tune icon opens Search Assets with its full filter set.
class FindAssetCard extends ConsumerStatefulWidget {
  const FindAssetCard({super.key});

  @override
  ConsumerState<FindAssetCard> createState() => _FindAssetCardState();
}

class _FindAssetCardState extends ConsumerState<FindAssetCard> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final input = _controller.text.trim();
    FocusScope.of(context).unfocus();

    if (input.isEmpty) {
      context.push('/assets/search');
      return;
    }

    if (input.contains(RegExp(r'\s'))) {
      _openSearch(input);
      return;
    }

    setState(() => _busy = true);
    try {
      final asset = await ref.read(assetsApiProvider).getByCode(input);
      if (!mounted) return;
      _controller.clear();
      context.push('/assets/${asset.id}', extra: asset);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isNotFound) {
        _openSearch(input);
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openSearch(String text) {
    _controller.clear();
    context.push(
      Uri(path: '/assets/search', queryParameters: {'q': text}).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Find an asset', style: context.text.titleLarge),
            const SizedBox(height: 2),
            Text(
              'Scan its label, or type a code or name.',
              style: context.mutedSmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            _ScanButton(onTap: () => context.push('/scan')),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _controller,
              enabled: !_busy,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'Asset code or name',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _busy
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.tune),
                        tooltip: 'Search with filters',
                        onPressed: () => context.push('/assets/search'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.text;
    const accent = CoreGridBrand.orangeDeep;
    const foreground = Colors.white;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.control),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Material(
        color: accent,
        borderRadius: BorderRadius.circular(AppRadius.control),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: foreground.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppRadius.tile),
                  ),
                  child: const Icon(Icons.qr_code_scanner, color: foreground),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan QR code',
                        style: textTheme.titleSmall?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Point your camera at the asset label',
                        style: textTheme.bodySmall?.copyWith(
                          color: foreground.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward, color: foreground, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
