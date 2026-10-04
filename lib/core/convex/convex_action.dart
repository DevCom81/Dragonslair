import 'dart:async';

import '../errors/app_exception.dart';
import 'convex_auth_binder.dart';
import 'convex_errors.dart';
import 'convex_gateway.dart';

const convexGameMasterTimeout = Duration(seconds: 35);
const convexScenarioTimeout = Duration(seconds: 40);
const convexBillingTimeout = Duration(seconds: 25);

Future<Object?> convexAction({
  required ConvexGateway gateway,
  required ConvexAuthBinder binder,
  required String name,
  Map<String, Object?> args = const {},
  Duration timeout = convexGameMasterTimeout,
}) async {
  final ready = await binder.ensureAuthenticated();
  if (!ready) {
    throw const AppAuthException('Convex n est pas authentifie.');
  }
  try {
    return await gateway.action(name, args).timeout(timeout);
  } on TimeoutException catch (error) {
    throw NetworkException(_timeoutMessage(name), cause: error);
  } catch (error) {
    throwMappedConvexError(error);
  }
}

Future<Object?> convexQuery({
  required ConvexGateway gateway,
  required ConvexAuthBinder binder,
  required String name,
  Map<String, Object?> args = const {},
}) async {
  final ready = await binder.ensureAuthenticated();
  if (!ready) {
    throw const AppAuthException('Convex n est pas authentifie.');
  }
  try {
    return await gateway.query(name, args);
  } catch (error) {
    throwMappedConvexError(error);
  }
}

String _timeoutMessage(String name) {
  if (name == 'gameMaster:generate') {
    return 'La generation du scenario ne repond pas.';
  }
  if (name.startsWith('gameMaster:')) {
    return 'Le backend MJ IA ne repond pas.';
  }
  if (name.startsWith('stripe:') || name.startsWith('googlePlay:')) {
    return 'Le backend achat ne repond pas.';
  }
  if (name.startsWith('downloads:')) {
    return 'Telechargement indisponible pour le moment.';
  }
  return 'Le serveur ne repond pas.';
}
