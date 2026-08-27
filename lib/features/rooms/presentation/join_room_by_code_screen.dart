import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/language_button.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../access/presentation/access_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/join_code.dart';
import 'room_navigation.dart';
import 'room_providers.dart';

class JoinRoomByCodeScreen extends ConsumerStatefulWidget {
  const JoinRoomByCodeScreen({super.key});

  @override
  ConsumerState<JoinRoomByCodeScreen> createState() =>
      _JoinRoomByCodeScreenState();
}

class _JoinRoomByCodeScreenState extends ConsumerState<JoinRoomByCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  var _isSubmitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.joinCodeTitle),
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
                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: JoinCode.length,
                  decoration: InputDecoration(
                    labelText: l10n.joinCodeLabel,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (JoinCode.normalize(value ?? '').length !=
                        JoinCode.length) {
                      return l10n.joinCodeInvalid;
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
                      : Text(l10n.join),
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

    final user = ref.read(authControllerProvider).value;
    final l10n = AppLocalizations.of(context);
    if (user == null) {
      _showError(l10n.authRequired);
      return;
    }
    final entitlement = await ref.read(currentEntitlementProvider.future);
    if (entitlement?.level.isDemo == true) {
      _showError(l10n.demoCannotJoin);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final room = await ref
          .read(roomRepositoryProvider)
          .fetchRoomByJoinCode(_codeController.text);
      if (room == null) {
        _showError(l10n.noRoomForCode);
        return;
      }
      if (!mounted) {
        return;
      }
      await openRoomForCurrentUser(
        context: context,
        ref: ref,
        room: room,
      );
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
