import 'package:dragons_lair/app/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('home screen renders without Supabase config', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DragonsLairApp()));

    expect(find.text('DragonsLair'), findsOneWidget);
    expect(find.text('Entrer dans la taverne'), findsOneWidget);
    expect(find.text('Creer une partie'), findsOneWidget);
    expect(find.text('Rejoindre une partie'), findsOneWidget);
  });
}
