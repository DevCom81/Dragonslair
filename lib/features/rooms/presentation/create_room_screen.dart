import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_labels.dart';
import '../../../core/l10n/language_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../scenarios/domain/scenario_definition.dart';
import 'room_providers.dart';

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  var _scenario = ScenarioCatalog.dungeon;
  var _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.createRoomTitle),
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.roomName,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.fieldRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text(l10n.scenario, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              RadioGroup<ScenarioDefinition>(
                groupValue: _scenario,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _scenario = value);
                  }
                },
                child: Column(
                  children: [
                    for (final scenario in ScenarioCatalog.all)
                      RadioListTile<ScenarioDefinition>(
                        contentPadding: EdgeInsets.zero,
                        value: scenario,
                        title: Text(
                          l10n.scenarioMinPlayers(
                            localizedScenarioName(l10n, scenario.id),
                            scenario.minPlayers,
                          ),
                        ),
                        subtitle: Text(
                          localizedScenarioDescription(l10n, scenario.id),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.create),
              ),
            ],
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
    final l10n = AppLocalizations.of(context);
    if (user == null) {
      _showError(l10n.authRequired);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final room = await ref.read(roomRepositoryProvider).createRoom(
            name: _nameController.text.trim(),
            hostId: user.id,
            scenarioId: _scenario.id,
            scenarioName: localizedScenarioName(l10n, _scenario.id),
            minPlayers: _scenario.minPlayers,
            requiredClassIds: _scenario.requiredClassIds,
          );
      if (mounted) {
        context.pushNamed('figurines', pathParameters: {'roomId': room.id});
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
