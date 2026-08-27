import 'package:dragons_lair/app/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('home screen renders launch actions without Supabase config',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DragonsLairApp()));

    expect(find.text('DragonsLair'), findsOneWidget);
    expect(find.text("Jouer sans s'inscrire"), findsOneWidget);
    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text('Inscription'), findsOneWidget);
    expect(find.text('Tester le MJ IA'), findsNothing);
  });
}
