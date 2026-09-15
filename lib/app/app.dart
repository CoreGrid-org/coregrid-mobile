import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/theme/app_theme.dart';
import 'router.dart';

/// Removes Android's stretch/glow overscroll effect app-wide and disables
/// the bounce-back rubber-banding at the top/bottom of a scroll view in
/// favour of a plain stop at the edge, a firmer, more "enterprise app"
/// feel than the platform default.
class _NoOverscrollBehavior extends MaterialScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}

class CoreGridApp extends ConsumerWidget {
  const CoreGridApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'CoreGrid Mobile',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
      scrollBehavior: _NoOverscrollBehavior(),
      debugShowCheckedModeBanner: false,
    );
  }
}
