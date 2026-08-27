import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/profile_repository.dart';
import 'auth_controller.dart';
import 'profile_providers.dart';

class DisplayNameScreen extends ConsumerStatefulWidget {
  const DisplayNameScreen({super.key});

  @override
  ConsumerState<DisplayNameScreen> createState() => _DisplayNameScreenState();
}

class _DisplayNameScreenState extends ConsumerState<DisplayNameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  var _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ton pseudo')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Choisis un nom visible par les autres joueurs de ta partie.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  maxLength: 32,
                  decoration: const InputDecoration(
                    labelText: 'Pseudo',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.length < 2) {
                      return 'Au moins 2 caracteres.';
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
                      : const Text('Enregistrer'),
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

    final user = ref.read(authControllerProvider).value;
    if (user == null) {
      _showError('Authentification requise.');
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
        context.goNamed('home');
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
