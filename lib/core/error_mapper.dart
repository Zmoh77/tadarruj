import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_localizations.dart';

String mapAuthError(Object error, AppLocalizations l10n) {
  final raw = error.toString().toLowerCase();

  if (raw.contains('free_limit_reached')) {
    return l10n.errFreeLimitReached;
  }

  if (error is AuthException) {
    final msg = error.message.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials')) {
      return l10n.errInvalidCredentials;
    }
    if (msg.contains('already registered') ||
        msg.contains('user already exists')) {
      return l10n.errEmailAlreadyUsed;
    }
    if (msg.contains('password') && msg.contains('6')) {
      return l10n.errWeakPassword;
    }
    if (msg.contains('invalid email') ||
        msg.contains('unable to validate email')) {
      return l10n.errInvalidEmail;
    }
  }

  if (raw.contains('socketexception') ||
      raw.contains('failed host lookup') ||
      raw.contains('network') ||
      raw.contains('clientexception')) {
    return l10n.errNetwork;
  }

  return l10n.errorGeneric;
}
