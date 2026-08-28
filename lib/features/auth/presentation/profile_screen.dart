import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/language_button.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../figurines/presentation/figurine_picker.dart';
import '../domain/profile_repository.dart';
import 'auth_controller.dart';
import 'profile_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  var _prefilled = false;
  int? _figurineId;
  var _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _prefillFromProfile() {
    if (_prefilled) {
      return;
    }
    final profile = ref.read(currentProfileProvider).value;
    if (profile == null) {
      return;
    }
    _prefilled = true;
    _nameController.text = profile.displayName;
    _figurineId = profile.avatarFigurineId;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ref.watch(currentProfileProvider);
    _prefillFromProfile();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: Padding(
          padding: context.pagePadding,
          child: ContentConstraint(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.profileHint,
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
                  const SizedBox(height: 8),
                  Text(
                    l10n.chooseAvatar,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: AppColors.gold),
                  ),
                  Expanded(
                    child: FigurinePickerGrid(
                      selectedId: _figurineId,
                      onSelected: (id) {
                        setState(() => _figurineId = id);
                      },
                    ),
                  ),
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
      await ref
          .read(profileRepositoryProvider)
          .upsertDisplayName(
            userId: user.id,
            displayName: _nameController.text,
          );
      await ref
          .read(profileRepositoryProvider)
          .upsertAvatar(userId: user.id, figurineId: _figurineId);
      ref.invalidate(currentProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.profileSaved)));
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
