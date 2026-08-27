import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/join_code.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Rejoindre par code')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: JoinCode.length,
                  decoration: const InputDecoration(
                    labelText: 'Code de partie',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (JoinCode.normalize(value ?? '').length !=
                        JoinCode.length) {
                      return 'Le code doit contenir 6 caracteres.';
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
                      : const Text('Rejoindre'),
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
      final room = await ref
          .read(roomRepositoryProvider)
          .fetchRoomByJoinCode(_codeController.text);
      if (room == null) {
        _showError('Aucune partie trouvee pour ce code.');
        return;
      }
      if (mounted) {
        context.goNamed('figurines', pathParameters: {'roomId': room.id});
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
