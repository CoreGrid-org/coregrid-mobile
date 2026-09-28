import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/ui.dart';
import 'auth_config.dart';

/// Opens ThunderID's hosted password-recovery page in the external browser
/// — never a WebView (RFC 8252 / SEC-ID-06: the user sees ThunderID's own
/// address bar, and CoreGrid never handles the password). The user enters
/// their sign-in email, gets a single-use link, and chooses a new password;
/// an existing session stays signed in.
///
/// When the recovery page isn't configured for this build, or no browser
/// can open it, explains the alternatives instead of failing silently.
Future<void> openPasswordRecovery(BuildContext context, {Uri? url}) async {
  final target = url ?? AuthConfig.passwordRecoveryUrl;
  var opened = false;
  if (target != null) {
    try {
      opened = await launchUrl(target, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
  }
  if (opened || !context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.lock_reset_rounded),
      title: const Text('Reset your password'),
      content: Text(
        target == null
            ? 'Password reset isn\'t set up in this build of the app. Use '
                  '"Forgot password?" on the ThunderID sign-in page, or ask a '
                  'CoreGrid Administrator to reset it for you.'
            : 'Couldn\'t open a browser for ThunderID\'s password reset. Use '
                  '"Forgot password?" on the ThunderID sign-in page, or ask a '
                  'CoreGrid Administrator to reset it for you.',
        style: context.mutedBody,
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
