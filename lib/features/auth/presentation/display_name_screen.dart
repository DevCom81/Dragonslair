import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/language_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/profile_repository.dart';
import 'auth_controller.dart';
import 'onboarding.dart';
import 'profile_providers.dart';

class DisplayNameScreen extends ConsumerStatefulWidget {
  const DisplayNameScreen({super.key});

  @override
  ConsumerState<DisplayNameScreen> createState() => _DisplayNameScreenState();
}

class _DisplayNameScreenState extends ConsumerState<DisplayNameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  var _prefilled = false;
  var _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authControllerProvider).value;
    if (!_prefilled && user != null && user.isAnonymous) {
      _prefilled = true;
      final suffix = user.id.replaceAll('-', '');
      final end = suffix.length < 4 ? suffix.length : 4;
      _nameController.text = l10n.guestSuggestedName(suffix.substring(0, end));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.displayNameTitle),
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.displayNameHint,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  maxLength: 32,
                  decoration: InputDecoration(
                    labelText: l10n.displayNameLabel,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.length < 2) {
                      return l10n.minTwoChars;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.save),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final l10n = AppLocalizations.of(context);
    final user = ref.read(authControllerProvider).value;
    if (user == null) {
      _showError(l10n.authRequired);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(profileRepositoryProvider).upsertDisplayName(
            userId: user.id,
            displayName: _nameController.text,
          );
      ref.invalidate(currentProfileProvider);
      if (mounted) {
        await routeAfterSession(context, ref);
      }
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }
}
