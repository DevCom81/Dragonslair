import '../errors/app_exception.dart';
import 'convex_auth_binder.dart';
import 'convex_errors.dart';
import 'convex_gateway.dart';

Future<Object?> convexMutate({
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
    return await gateway.mutate(name, args);
  } catch (error) {
    throwMappedConvexError(error);
  }
}
