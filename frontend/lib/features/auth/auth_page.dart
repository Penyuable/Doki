import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import 'auth_cubit.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegister = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    final pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!pattern.hasMatch(email)) {
      return AppStrings.of(context).t('auth.validationEmail');
    }
    return null;
  }

  String? _validateUsername(String? value) {
    final username = (value ?? '').trim();
    if (!RegExp(r'^[A-Za-z0-9_]{3,16}$').hasMatch(username)) {
      return AppStrings.of(context).t('auth.validationUsername');
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').length < 8) {
      return AppStrings.of(context).t('auth.validationPassword');
    }
    return null;
  }

  void _toggleMode() {
    setState(() => _isRegister = !_isRegister);
    context.read<AuthCubit>().clearMessage();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final cubit = context.read<AuthCubit>();
    if (_isRegister) {
      await cubit.register(
        email: _emailController.text,
        username: _usernameController.text,
        password: _passwordController.text,
      );
    } else {
      await cubit.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: BlocBuilder<AuthCubit, AuthState>(
                  builder: (context, state) {
                    final isLoading = state is AuthLoading;
                    final message = state is AuthUnauthenticated
                        ? state.sessionExpired
                              ? strings.t('auth.sessionExpired')
                              : state.message
                        : null;

                    return AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _brand(strings),
                            const SizedBox(height: 32),
                            Text(
                              _isRegister
                                  ? strings.t('auth.registerCta')
                                  : strings.t('auth.welcomeBack'),
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              strings.t('auth.subtitle'),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _emailController,
                              enabled: !isLoading,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const <String>[
                                AutofillHints.email,
                              ],
                              autocorrect: false,
                              decoration: InputDecoration(
                                labelText: strings.t('auth.email'),
                                hintText: strings.t('auth.hintEmail'),
                                prefixIcon: const Icon(
                                  Icons.alternate_email_rounded,
                                  size: 20,
                                ),
                              ),
                              validator: _validateEmail,
                            ),
                            if (_isRegister) ...<Widget>[
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _usernameController,
                                enabled: !isLoading,
                                textInputAction: TextInputAction.next,
                                autofillHints: const <String>[
                                  AutofillHints.newUsername,
                                ],
                                autocorrect: false,
                                decoration: InputDecoration(
                                  labelText: strings.t('auth.username'),
                                  hintText: strings.t('auth.hintUsername'),
                                  prefixIcon: const Icon(
                                    Icons.person_outline_rounded,
                                    size: 20,
                                  ),
                                ),
                                validator: _validateUsername,
                              ),
                            ],
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordController,
                              enabled: !isLoading,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: <String>[
                                _isRegister
                                    ? AutofillHints.newPassword
                                    : AutofillHints.password,
                              ],
                              onFieldSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: strings.t('auth.password'),
                                hintText: strings.t('auth.hintPassword'),
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                  size: 20,
                                ),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  tooltip: _obscurePassword
                                      ? 'Tampilkan password'
                                      : 'Sembunyikan password',
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    size: 20,
                                  ),
                                ),
                              ),
                              validator: _validatePassword,
                            ),
                            if (message != null && message.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 16),
                              _ErrorBanner(message: message),
                            ],
                            const SizedBox(height: 22),
                            FilledButton(
                              onPressed: isLoading ? null : _submit,
                              child: isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _isRegister
                                          ? strings.t('auth.register')
                                          : strings.t('auth.login'),
                                    ),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: isLoading ? null : _toggleMode,
                              child: Text(
                                _isRegister
                                    ? strings.t('auth.toLogin')
                                    : strings.t('auth.toRegister'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _brand(AppStrings strings) {
    return Row(
      children: <Widget>[
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[AppTheme.primary, AppTheme.accent],
            ),
          ),
          child: const Icon(
            Icons.auto_awesome_mosaic_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              strings.t('app.name'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
            Text(
              strings.t('app.tagline'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF7F1D1D).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF87171).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: Color(0xFFFCA5A5),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFFFCA5A5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
