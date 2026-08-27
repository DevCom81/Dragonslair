import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/l10n_labels.dart';
import '../../../core/l10n/language_button.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../scenarios/domain/custom_scenario_draft.dart';
import '../../scenarios/domain/scenario_definition.dart';
import '../../scenarios/presentation/scenario_providers.dart';
import 'room_providers.dart';

enum _CreateMode { custom, catalog }

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _promptController = TextEditingController();
  final _titleController = TextEditingController();
  final _toneController = TextEditingController();
  var _mode = _CreateMode.catalog;
  var _scenario = ScenarioCatalog.dungeon;
  var _draft = const CustomScenarioDraft();
  var _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _promptController.dispose();
    _titleController.dispose();
    _toneController.dispose();
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
            padding: context.pagePadding,
            children: [
              ContentConstraint(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.newAdventureTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text(l10n.createMyAdventure),
                          selected: _mode == _CreateMode.custom,
                          onSelected: (_) {
                            setState(() => _mode = _CreateMode.custom);
                          },
                        ),
                        ChoiceChip(
                          label: Text(l10n.readyAdventures),
                          selected: _mode == _CreateMode.catalog,
                          onSelected: (_) {
                            setState(() => _mode = _CreateMode.catalog);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _nameField(l10n),
                    const SizedBox(height: 16),
                    if (_mode == _CreateMode.catalog)
                      _scenarioPicker(context, l10n)
                    else
                      _customForm(context, l10n),
                    const SizedBox(height: 16),
                    _submitButton(l10n),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nameField(AppLocalizations l10n) {
    return TextFormField(
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
    );
  }

  Widget _scenarioPicker(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
      ],
    );
  }

  Widget _customForm(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _promptController,
          minLines: 4,
          maxLines: 8,
          decoration: InputDecoration(
            labelText: l10n.adventurePromptLabel,
            hintText: l10n.adventurePromptHint,
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          onChanged: (value) {
            _draft = _draft.copyWith(prompt: value);
          },
          validator: (value) {
            if (_mode != _CreateMode.custom) {
              return null;
            }
            if (value == null || value.trim().length < scenarioPromptMinLength) {
              return l10n.adventurePromptTooShort;
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: l10n.adventureTitleOptional,
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            _draft = _draft.copyWith(title: value);
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _toneController,
          decoration: InputDecoration(
            labelText: l10n.adventureToneOptional,
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            _draft = _draft.copyWith(tone: value);
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ScenarioDifficulty>(
          initialValue: _draft.difficulty,
          decoration: InputDecoration(
            labelText: l10n.adventureDifficulty,
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(
              value: ScenarioDifficulty.easy,
              child: Text(l10n.difficultyEasy),
            ),
            DropdownMenuItem(
              value: ScenarioDifficulty.standard,
              child: Text(l10n.difficultyStandard),
            ),
            DropdownMenuItem(
              value: ScenarioDifficulty.hard,
              child: Text(l10n.difficultyHard),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _draft = _draft.copyWith(difficulty: value));
            }
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ScenarioDuration>(
          initialValue: _draft.duration,
          decoration: InputDecoration(
            labelText: l10n.adventureDuration,
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(
              value: ScenarioDuration.short,
              child: Text(l10n.durationShort),
            ),
            DropdownMenuItem(
              value: ScenarioDuration.medium,
              child: Text(l10n.durationMedium),
            ),
            DropdownMenuItem(
              value: ScenarioDuration.long,
              child: Text(l10n.durationLong),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _draft = _draft.copyWith(duration: value));
            }
          },
        ),
        const SizedBox(height: 12),
        Text(l10n.adventureOrientation),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final orientation in ScenarioOrientation.values)
              FilterChip(
                label: Text(_orientationLabel(l10n, orientation)),
                selected: _draft.orientations.contains(orientation),
                onSelected: (selected) {
                  final next = {..._draft.orientations};
                  if (selected) {
                    next.add(orientation);
                  } else {
                    next.remove(orientation);
                  }
                  setState(() => _draft = _draft.copyWith(orientations: next));
                },
              ),
          ],
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _draft.improvise,
          onChanged: (value) {
            setState(
              () => _draft = _draft.copyWith(improvise: value ?? true),
            );
          },
          title: Text(l10n.optionImprovise),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _draft.permadeath,
          onChanged: (value) {
            setState(
              () => _draft = _draft.copyWith(permadeath: value ?? false),
            );
          },
          title: Text(l10n.optionPermadeath),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _draft.pvp,
          onChanged: (value) {
            setState(() => _draft = _draft.copyWith(pvp: value ?? false));
          },
          title: Text(l10n.optionPvp),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _draft.betrayals,
          onChanged: (value) {
            setState(
              () => _draft = _draft.copyWith(betrayals: value ?? false),
            );
          },
          title: Text(l10n.optionBetrayals),
        ),
      ],
    );
  }

  String _orientationLabel(
    AppLocalizations l10n,
    ScenarioOrientation orientation,
  ) {
    return switch (orientation) {
      ScenarioOrientation.combat => l10n.orientationCombat,
      ScenarioOrientation.exploration => l10n.orientationExploration,
      ScenarioOrientation.investigation => l10n.orientationInvestigation,
      ScenarioOrientation.roleplay => l10n.orientationRoleplay,
      ScenarioOrientation.survival => l10n.orientationSurvival,
    };
  }

  Widget _submitButton(AppLocalizations l10n) {
    return FilledButton(
      onPressed: _isSubmitting ? null : _submit,
      child: _isSubmitting
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              _mode == _CreateMode.custom && AppConfig.isGameMasterRemote
                  ? l10n.generatingAdventure
                  : l10n.create,
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
      final custom = _mode == _CreateMode.custom;
      final draft = _draft.copyWith(
        prompt: _promptController.text,
        title: _titleController.text,
        tone: _toneController.text,
      );
      final scenarioName = custom
          ? (draft.title.trim().isEmpty
              ? l10n.scenarioCustomName
              : draft.title.trim())
          : localizedScenarioName(l10n, _scenario.id);
      final room = await ref.read(roomRepositoryProvider).createRoom(
            name: _nameController.text.trim(),
            hostId: user.id,
            scenarioId: custom ? ScenarioCatalog.custom.id : _scenario.id,
            scenarioName: scenarioName,
            minPlayers: custom ? 1 : _scenario.minPlayers,
            requiredClassIds: custom ? const [] : _scenario.requiredClassIds,
            scenarioPrompt: custom ? draft.prompt.trim() : '',
            worldState: custom && !AppConfig.isGameMasterRemote
                ? draft.mockWorldState()
                : const {},
          );
      if (custom && AppConfig.isGameMasterRemote) {
        await ref.read(scenarioGeneratorProvider).generate(
              roomId: room.id,
              draft: draft,
            );
      }
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
