import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/language_button.dart';
import '../../../core/responsive/responsive.dart';
import '../../../l10n/app_localizations.dart';
import 'auth_controller.dart';

class PasswordResetScreen extends ConsumerStatefulWidget {
  const PasswordResetScreen({super.key});

  @override
  ConsumerState<PasswordResetScreen> createState() =>
      _PasswordResetScreenState();
}

class _PasswordResetScreenState extends ConsumerState<PasswordResetScreen> {
  final _emailKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  var _isSubmitting = false;
  var _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.passwordResetTitle),
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: ListView(
          padding: context.pagePadding,
          children: [
            ContentConstraint(
              child: _emailSent ? _sentMessage(l10n) : _requestForm(l10n),
            ),
          ],
        ),
      ),
    );
  }

  Widget _requestForm(AppLocalizations l10n) {
    return Form(
      key: _emailKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.passwordResetHint,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(
              labelText: l10n.email,
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (!email.contains('@') || !email.contains('.')) {
                return l10n.emailInvalid;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isSubmitting ? null : _requestReset,
            child: _isSubmitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.sendResetEmail),
          ),
        ],
      ),
    );
  }

  Widget _sentMessage(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.passwordResetSent,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => context.goNamed(
            'auth',
            queryParameters: const {'mode': 'login'},
          ),
          child: Text(l10n.logIn),
        ),
      ],
    );
  }

  Future<void> _requestReset() async {
    if (!_emailKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await ref.read(authControllerProvider.notifier).requestPasswordReset(
            email: _emailController.text,
          );
    } catch (_) {
      // Same visible outcome whether or not the address exists.
    } finally {
      if (mounted) {
        setState(() {
          _emailSent = true;
          _isSubmitting = false;
        });
      }
    }
  }
}
