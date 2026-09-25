import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glmap_example/main.dart' as app;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('default entry initializes Core and opens the SDK catalog', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const codec = StandardMessageCodec();
    final calls = <String>[];
    for (final method in ['initialize', 'addAssetDataSet']) {
      final channel = 'dev.flutter.pigeon.glmap_core.CoreHostApi.$method';
      messenger.setMockMessageHandler(channel, (message) async {
        calls.add(method);
        return codec.encodeMessage(<Object?>[null]);
      });
      addTearDown(() => messenger.setMockMessageHandler(channel, null));
    }
    await app.main();
    await tester.pumpAndSettle();
    expect(calls, ['initialize', 'addAssetDataSet']);
    expect(find.byType(app.DemoCatalog), findsOneWidget);
    expect(find.text('GLMap · Flutter'), findsOneWidget);
    expect(find.byKey(const Key('open-lifecycle')), findsOneWidget);
    expect(app.demos, hasLength(20));
    expect(find.textContaining('Initialization failed'), findsNothing);
  });
}
