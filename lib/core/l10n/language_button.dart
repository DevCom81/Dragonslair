import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/music/presentation/music_controller.dart';
import '../../l10n/app_localizations.dart';
import 'locale_controller.dart';

class LanguageButton extends ConsumerWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      tooltip: l10n.preferences,
      onPressed: () => _showLanguageSheet(context, ref),
      icon: const Icon(Icons.language),
    );
  }

  Future<void> _showLanguageSheet(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = ref.read(localeControllerProvider);

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(title: Text(l10n.preferences)),
                RadioGroup<Locale>(
                  groupValue: current,
                  onChanged: (value) async {
                    if (value == null) {
                      return;
                    }
                    await ref
                        .read(localeControllerProvider.notifier)
                        .setLocale(value);
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final locale in supportedAppLocales)
                        RadioListTile<Locale>(
                          value: locale,
                          title: Text(_label(l10n, locale.languageCode)),
                        ),
                    ],
                  ),
                ),
                const Divider(),
                Consumer(
                  builder: (context, ref, _) {
                    final music = ref.watch(musicControllerProvider);
                    return Column(
                      children: [
                        SwitchListTile(
                          title: Text(l10n.musicToggle),
                          value: !music.isMuted,
                          onChanged: (_) {
                            ref
                                .read(musicControllerProvider.notifier)
                                .toggleMute();
                          },
                        ),
                        ListTile(
                          title: Text(l10n.musicVolume),
                          subtitle: Slider(
                            value: music.volume,
                            onChanged: (value) {
                              ref
                                  .read(musicControllerProvider.notifier)
                                  .setVolume(value);
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _label(AppLocalizations l10n, String code) {
    return switch (code) {
      'fr' => l10n.languageFrench,
      'en' => l10n.languageEnglish,
      'es' => l10n.languageSpanish,
      'de' => l10n.languageGerman,
      _ => code,
    };
  }
}
