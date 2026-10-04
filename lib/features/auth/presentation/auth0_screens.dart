import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/language_button.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import 'auth_controller.dart';
import 'onboarding.dart';

class Auth0LoginScreen extends ConsumerStatefulWidget {
  const Auth0LoginScreen({this.contextToken, super.key});

  final String? contextToken;

  @override
  ConsumerState<Auth0LoginScreen> createState() => _Auth0LoginScreenState();
}

class _Auth0LoginScreenState extends ConsumerState<Auth0LoginScreen> {
  var _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _start();
    });
  }

  Future<void> _start() async {
    if (_started || !mounted) {
      return;
    }
    _started = true;
    try {
      await ref.read(authControllerProvider.notifier).startSignIn(
            context: widget.contextToken,
          );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppColors.danger,
        ),
      );
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.logIn),
        actions: const [LanguageButton()],
      ),
      body: const SafeArea(
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class Auth0CallbackScreen extends ConsumerStatefulWidget {
  const Auth0CallbackScreen({super.key});

  @override
  ConsumerState<Auth0CallbackScreen> createState() =>
      _Auth0CallbackScreenState();
}

class _Auth0CallbackScreenState extends ConsumerState<Auth0CallbackScreen> {
  var _routed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _finish();
    });
  }

  Future<void> _finish() async {
    if (_routed || !mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(authControllerProvider.future);
      final user = ref.read(authControllerProvider).value;
      if (!mounted) {
        return;
      }
      if (user == null) {
        _routed = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.authSignInFailed),
            backgroundColor: AppColors.danger,
          ),
        );
        context.go('/');
        return;
      }
      _routed = true;
      await routeAfterSession(context, ref);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _routed = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppColors.danger,
        ),
      );
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(actions: const [LanguageButton()]),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: context.pagePadding,
            child: const CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }
}
