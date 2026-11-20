import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/locale_provider.dart';
import '../../app/theme_provider.dart';
import '../../core/error_mapper.dart';
import '../../core/supabase_client.dart';
import '../../core/tadarruj_brand.dart';
import '../../l10n/app_localizations.dart';

enum _AuthMode { login, signup, resetPassword }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _AuthMode _mode = _AuthMode.login;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _switchMode(_AuthMode newMode) {
    setState(() {
      _mode = newMode;
      _errorMessage = null;
      _infoMessage = null;
    });
  }

  Future<void> _submit() async {
    if (_isLoading) return;

    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final displayName = _nameController.text.trim();

    if (email.isEmpty ||
        (_mode != _AuthMode.resetPassword && password.isEmpty)) {
      setState(() {
        _errorMessage = l10n.errEmptyFields;
        _infoMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    final client = ref.read(supabaseClientProvider);
    final currentLang = ref.read(localeProvider).languageCode;

    try {
      if (_mode == _AuthMode.login) {
        await client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } else if (_mode == _AuthMode.signup) {
        final response = await client.auth.signUp(
          email: email,
          password: password,
          data: {
            'display_name': displayName,
            'full_name': displayName,
          },
        );

        final userId = response.user?.id;
        if (userId != null && response.session != null) {
          await client
              .from('profiles')
              .update({'locale': currentLang}).eq('id', userId);
        } else if (mounted) {
          setState(() {
            _infoMessage = l10n.signupSuccessCheckEmail;
          });
        }
      } else {
        await client.auth.resetPasswordForEmail(email);
        if (mounted) {
          setState(() {
            _infoMessage = l10n.resetEmailSent;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = mapAuthError(e, l10n);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final currentLang = ref.watch(localeProvider).languageCode;
    final isAr = currentLang == 'ar';
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    final String title;
    final String subtitle;
    final String buttonLabel;
    switch (_mode) {
      case _AuthMode.login:
        title = l10n.authLoginTitle;
        subtitle = isAr
            ? 'أهلاً بعودتك إلى مسارك القرآني الهادئ'
            : (currentLang == 'fr'
                ? 'Retrouve ton compagnon de mémorisation sereine'
                : 'Welcome back to your calm Quran companion');
        buttonLabel = l10n.loginButton;
        break;
      case _AuthMode.signup:
        title = l10n.authSignupTitle;
        subtitle = isAr
            ? 'ابدأ رحلة الحفظ والمراجعة خطوة بخطوة'
            : (currentLang == 'fr'
                ? 'Commence ton parcours pas à pas, avec constance'
                : 'Begin your memorization journey step by step');
        buttonLabel = l10n.signupButton;
        break;
      case _AuthMode.resetPassword:
        title = l10n.authResetTitle;
        subtitle = isAr
            ? 'أدخل بريدك الإلكتروني لاستعادة الوصول إلى حسابك'
            : (currentLang == 'fr'
                ? 'Saisis ton adresse e-mail pour recevoir un lien'
                : 'Enter your email to receive a reset link');
        buttonLabel = l10n.sendResetButton;
        break;
    }

    return Scaffold(
      body: Stack(
        children: [
          const IslamicPatternOverlay(opacity: 0.035),
          SafeArea(
            child: Column(
              children: [
                // Barre supérieure harmonisée avec sélecteur de langue et thème
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const TadarrujLogo(size: 32, showTitle: false),
                      const SizedBox(width: 10),
                      Text(
                        isAr ? 'تَدَرُّج' : 'Tadarruj',
                        style: GoogleFonts.elMessiri(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? TadarrujColors.goldSoft
                              : TadarrujColors.emeraldDeep,
                        ),
                      ),
                      const Spacer(),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: ['fr', 'en', 'ar'].contains(currentLang)
                              ? currentLang
                              : 'fr',
                          icon: Icon(
                            Icons.language_rounded,
                            size: 18,
                            color: cs.primary,
                          ),
                          style: TextStyle(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'fr', child: Text('FR')),
                            DropdownMenuItem(value: 'en', child: Text('EN')),
                            DropdownMenuItem(value: 'ar', child: Text('عربي')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              ref.read(localeProvider.notifier).state =
                                  Locale(val);
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isDark
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                          size: 20,
                          color: cs.primary,
                        ),
                        onPressed: () {
                          ref.read(themeModeProvider.notifier).state =
                              isDark ? ThemeMode.light : ThemeMode.dark;
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(
                                  child: TadarrujLogo(
                                    size: 64,
                                    showTitle: true,
                                    titleColor: isDark
                                        ? TadarrujColors.goldSoft
                                        : TadarrujColors.emeraldDeep,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  title,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(height: 22),

                                if (_mode == _AuthMode.signup) ...[
                                  TextField(
                                    controller: _nameController,
                                    textInputAction: TextInputAction.next,
                                    decoration: InputDecoration(
                                      labelText: l10n.nameLabel,
                                      prefixIcon: const Icon(Icons.person_outline),
                                      filled: true,
                                      fillColor: cs.surface,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                ],

                                TextField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: _mode == _AuthMode.resetPassword
                                      ? TextInputAction.done
                                      : TextInputAction.next,
                                  decoration: InputDecoration(
                                    labelText: l10n.emailLabel,
                                    prefixIcon: const Icon(Icons.email_outlined),
                                    filled: true,
                                    fillColor: cs.surface,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                if (_mode != _AuthMode.resetPassword) ...[
                                  TextField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => _submit(),
                                    decoration: InputDecoration(
                                      labelText: l10n.passwordLabel,
                                      prefixIcon: const Icon(Icons.lock_outline),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _obscurePassword = !_obscurePassword;
                                          });
                                        },
                                      ),
                                      filled: true,
                                      fillColor: cs.surface,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                ],

                                if (_mode == _AuthMode.login)
                                  Align(
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: TextButton(
                                      onPressed: _isLoading
                                          ? null
                                          : () => _switchMode(_AuthMode.resetPassword),
                                      child: Text(l10n.forgotPasswordLink),
                                    ),
                                  ),

                                const SizedBox(height: 12),

                                if (_errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: cs.errorContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: cs.onErrorContainer,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                ],

                                if (_infoMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: TadarrujColors.sageSoft,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _infoMessage!,
                                      style: const TextStyle(
                                        color: TadarrujColors.emeraldDeep,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                ],

                                SizedBox(
                                  height: 52,
                                  child: FilledButton(
                                    onPressed: _isLoading ? null : _submit,
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(buttonLabel),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                if (_mode == _AuthMode.login)
                                  TextButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () => _switchMode(_AuthMode.signup),
                                    child: Text(l10n.noAccountLink),
                                  )
                                else if (_mode == _AuthMode.signup)
                                  TextButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () => _switchMode(_AuthMode.login),
                                    child: Text(l10n.hasAccountLink),
                                  )
                                else
                                  TextButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () => _switchMode(_AuthMode.login),
                                    child: Text(l10n.backToLoginLink),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
