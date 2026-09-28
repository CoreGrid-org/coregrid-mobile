import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../theme/app_theme.dart';
import 'status_pill.dart';
import 'surfaces.dart';

/// Plain-language text for any error a provider surfaces — never a raw
/// exception string (mobile-specification.md §3.4).
String errorMessageFor(Object error, {String? fallback}) {
  if (error is ApiException) {
    if (error.isNetworkError) {
      return 'You\'re offline or CoreGrid can\'t be reached. '
          'Check your connection and try again.';
    }
    return error.message;
  }
  return fallback ?? 'Something went wrong. Try again.';
}

/// Centered spinner for a whole-page load.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

/// Centered icon + title + message (+ optional action), for empty lists and
/// failed loads. Scrollable so it works inside a [RefreshIndicator].
class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.tone,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final StatusTone? tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconTile(icon, tone: tone, size: 64),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: context.text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: AppSpacing.xs + 2),
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: context.mutedBody,
                    ),
                  ],
                  if (action != null) ...[
                    const SizedBox(height: AppSpacing.lg + 4),
                    action!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [MessageView] preset for a failed load, with a Retry button.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.error,
    required this.onRetry,
    this.title = 'Couldn\'t load this',
  });

  final Object error;
  final VoidCallback onRetry;
  final String title;

  @override
  Widget build(BuildContext context) {
    final offline =
        error is ApiException && (error as ApiException).isNetworkError;
    return MessageView(
      icon: offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
      tone: StatusTone.danger,
      title: offline ? 'You\'re offline' : title,
      message: errorMessageFor(error),
      action: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh, size: 20),
        label: const Text('Retry'),
      ),
    );
  }
}

/// The standard loading / empty / error / data switch for an [AsyncValue]
/// page body. Loading and error states are full-page; [data] builds the
/// populated state, [empty] (when [isEmpty] says so) the empty one.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    required this.onRetry,
    this.errorTitle = 'Couldn\'t load this',
    this.isEmpty,
    this.empty,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback onRetry;
  final String errorTitle;
  final bool Function(T data)? isEmpty;
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    return switch (value) {
      AsyncData(:final value)
          when empty != null && (isEmpty?.call(value) ?? false) =>
        empty!,
      AsyncData(:final value) => data(value),
      AsyncError(:final error) => ErrorView(
        error: error,
        title: errorTitle,
        onRetry: onRetry,
      ),
      _ => const LoadingView(),
    };
  }
}

