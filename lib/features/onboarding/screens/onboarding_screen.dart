import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/ui.dart';
import '../onboarding_providers.dart';

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
}

const _pages = [
  _OnboardingPageData(
    icon: Icons.qr_code_scanner,
    color: CoreGridBrand.orangeDeep,
    title: 'Scan & Identify',
    description:
        'Point your camera at an asset\'s QR label - or type the code - and '
        'get its full record in seconds.',
  ),
  _OnboardingPageData(
    icon: Icons.fact_check_outlined,
    color: CoreGridBrand.orange,
    title: 'Verify & Report',
    description:
        'Confirm an asset\'s presence, location and condition on the spot, '
        'or flag a fault the moment you see it - with a photo.',
  ),
  _OnboardingPageData(
    icon: Icons.dashboard_customize_outlined,
    color: Color(0xFFF59E0B),
    title: 'Stay On Top of Your Day',
    description:
        'See what\'s due, what\'s assigned to you, and what\'s moved '
        'forward - the moment you open the app.',
  ),
];

/// One-time intro (device-local — `OnboardingStorage`) shown before the
/// sign-in screen. Not an SRS requirement; a UX addition to this owner's
/// app-shell scope, gated so it only ever shows once per install. Route:
/// `/onboarding`, the app's `initialLocation`.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(onboardingStorageProvider).markSeen();
    if (mounted) context.go('/sign-in');
  }

  @override
  Widget build(BuildContext context) {
    final seen = ref.watch(onboardingSeenProvider);

    // Already shown on a prior launch — skip straight past without ever
    // painting a slide.
    if (seen.asData?.value == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/sign-in');
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [for (final p in _pages) _OnboardingPage(p)],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? context.colors.primary
                            : context.colors.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    if (_page == _pages.length - 1) {
                      _finish();
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  child: Text(
                    _page == _pages.length - 1 ? 'Get Started' : 'Next',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage(this.data);

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconTile(data.icon, color: data.color, size: 128),
          const SizedBox(height: 40),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: context.text.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: context.text.bodyLarge?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
