import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'locale_controller.dart';

class LanguageButton extends ConsumerWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      tooltip: l10n.language,
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
          child: RadioGroup<Locale>(
            groupValue: current,
            onChanged: (value) async {
              if (value == null) {
                return;
              }
              await ref.read(localeControllerProvider.notifier).setLocale(value);
              if (sheetContext.mounted) {
                Navigator.of(sheetContext).pop();
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(title: Text(l10n.preferences)),
                for (final locale in supportedAppLocales)
                  RadioListTile<Locale>(
                    value: locale,
                    title: Text(_label(l10n, locale.languageCode)),
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
