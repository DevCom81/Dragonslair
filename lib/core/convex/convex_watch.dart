import 'dart:async';

import '../../core/errors/app_exception.dart';
import 'convex_gateway.dart';

Stream<T> watchConvexQuery<T>({
  required ConvexGateway gateway,
  required String name,
  Map<String, Object?> args = const {},
  required T Function(Object? value) map,
}) {
  ConvexWatch? watch;
  StreamSubscription<Object?>? subscription;
  late final StreamController<T> controller;
  controller = StreamController<T>.broadcast(
    onListen: () {
      watch = gateway.subscribe(name, args);
      subscription = watch!.snapshots.listen(
        (value) {
          if (controller.isClosed) {
            return;
          }
          try {
            controller.add(map(value));
          } catch (error, stackTrace) {
            controller.addError(error, stackTrace);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (controller.isClosed) {
            return;
          }
          controller.addError(
            GameException(error.toString(), cause: error),
            stackTrace,
          );
        },
      );
    },
    onCancel: () {
      subscription?.cancel();
      subscription = null;
      watch?.cancel();
      watch = null;
    },
  );
  return controller.stream;
}
