import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/character_stats.dart';
import '../domain/profile_repository.dart';
import 'auth_controller.dart';
import 'profile_providers.dart';

class CharacterSheetScreen extends ConsumerStatefulWidget {
  const CharacterSheetScreen({super.key});

  @override
  ConsumerState<CharacterSheetScreen> createState() =>
      _CharacterSheetScreenState();
}

class _CharacterSheetScreenState extends ConsumerState<CharacterSheetScreen> {
  var _stats = CharacterStats.defaults;
  var _loaded = false;
  var _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).value;
    if (profile != null && !_loaded) {
      _stats = profile.stats;
      _loaded = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Fiche de personnage')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Ces caracteristiques restent liees a ton pseudo.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            for (final field in characterStatFields) ...[
              Text(field.label),
              Row(
                children: [
                  IconButton(
                    onPressed: field.read(_stats) <= CharacterStats.minValue
                        ? null
                        : () {
                            setState(() {
                              _stats = field.write(
                                _stats,
                                field.read(_stats) - 1,
                              );
                            });
                          },
                    icon: const Icon(Icons.remove),
                  ),
                  Text(
                    '${field.read(_stats)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    onPressed: field.read(_stats) >= CharacterStats.maxValue
                        ? null
                        : () {
                            setState(() {
                              _stats = field.write(
                                _stats,
                                field.read(_stats) + 1,
                              );
                            });
                          },
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enregistrer la fiche'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final user = ref.read(authControllerProvider).value;
    final profile = ref.read(currentProfileProvider).value;
    if (user == null || profile == null) {
      _showError('Pseudo requis avant la fiche.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(profileRepositoryProvider).upsertSheet(
            userId: user.id,
            displayName: profile.displayName,
            stats: _stats,
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
