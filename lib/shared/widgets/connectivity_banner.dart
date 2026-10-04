import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../connectivity/connectivity_provider.dart';
import '../theme/app_theme.dart';
import 'status_pill.dart';

enum _BannerMode { offline, backOnline }

/// App-wide connection banner, wrapped around every route in
/// `MaterialApp.builder`. Slides down under the status bar while the device
/// is offline, flips to a brief "Back online" when the connection returns,
/// then slides away. It pushes the page down (taking over the status-bar
/// inset) rather than covering the app bar.
class ConnectivityBanner extends ConsumerStatefulWidget {
  const ConnectivityBanner({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends ConsumerState<ConnectivityBanner>
    with SingleTickerProviderStateMixin {
  static const _backOnlineFor = Duration(milliseconds: 2500);

  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final _reveal = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  _BannerMode _mode = _BannerMode.offline;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<bool>>(isOnlineProvider, (_, next) {
      if (next.value case final online?) _onConnectivity(online);
    }, fireImmediately: true);
  }

  void _onConnectivity(bool online) {
    _hideTimer?.cancel();
    if (!online) {
      setState(() => _mode = _BannerMode.offline);
      _controller.forward();
    } else if (_controller.status != AnimationStatus.dismissed) {
      setState(() => _mode = _BannerMode.backOnline);
      _hideTimer = Timer(_backOnlineFor, _controller.reverse);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _reveal.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final inset = media.padding.top;
    return AnimatedBuilder(
      animation: _reveal,
      child: widget.child,
      builder: (context, child) {
        final t = _reveal.value;
        return Column(
          children: [
            if (t > 0)
              ClipRect(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  heightFactor: t,
                  child: _Banner(mode: _mode, topInset: inset),
                ),
              ),
            Expanded(
              // The banner owns the status-bar inset while shown, so the
              // page's own app bar doesn't pad for it a second time.
              child: MediaQuery(
                data: media.copyWith(
                  padding: media.padding.copyWith(top: inset * (1 - t)),
                  viewPadding: media.viewPadding.copyWith(
                    top: media.viewPadding.top * (1 - t),
                  ),
                ),
                child: child!,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.mode, required this.topInset});

  final _BannerMode mode;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    final offline = mode == _BannerMode.offline;
    final tone = offline ? StatusTone.danger : StatusTone.success;
    final fg = tone.foreground(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Material(
        color: tone.background(context),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            topInset + AppSpacing.sm + 2,
            AppSpacing.lg,
            AppSpacing.sm + 2,
          ),
          child: Row(
            children: [
              Icon(
                offline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                color: fg,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      offline ? 'No internet connection' : 'Back online',
                      style: context.text.bodyMedium?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (offline)
                      Text(
                        'Check Wi-Fi or mobile data. You can keep browsing '
                        'what\'s already loaded.',
                        style: context.text.bodySmall?.copyWith(color: fg),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
