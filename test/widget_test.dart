import 'package:flutter_test/flutter_test.dart';
import 'package:pulsemesh_app/main.dart';

void main() {
  testWidgets('PulseMesh dashboard loads', (WidgetTester tester) async {
    await tester.pumpWidget(const PulseMeshApp());
    expect(find.text('PulseMesh'), findsWidgets);
  });
}