import 'package:flutter_test/flutter_test.dart';
import 'package:small_ssh/app/app.dart';

void main() {
  testWidgets('renders app shell', (WidgetTester tester) async {
    await tester.pumpWidget(const SmallSshApp());
    await tester.pumpAndSettle();

    expect(find.text('small_ssh'), findsOneWidget);
    expect(find.text('Hosts'), findsOneWidget);
  });
}
