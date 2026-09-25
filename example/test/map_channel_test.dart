import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glmap/glmap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const codec = StandardMessageCodec();

  testWidgets(
    'platform view identity and Pigeon diagnostics preserve map ownership',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final creations = <Map<Object?, Object?>>[];
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
          call,
        ) async {
          if (call.method == 'create') {
            creations.add(Map<Object?, Object?>.from(call.arguments as Map));
          }
          return null;
        });
        addTearDown(
          () => messenger.setMockMethodCallHandler(
            SystemChannels.platform_views,
            null,
          ),
        );
        GLMapController? controller;
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: GLMap(onCreated: (value) => controller = value),
          ),
        );
        await tester.pump();
        expect(controller, isNotNull);
        expect(creations.single['viewType'], 'software.globus.glmap/view');
        final current = controller!;
        final channel =
            'dev.flutter.pigeon.glmap.MapHostApi.diagnostics.${current.viewId}';
        final disposeChannel =
            'dev.flutter.pigeon.glmap.MapHostApi.dispose.${current.viewId}';
        var calls = 0;
        messenger.setMockMessageHandler(channel, (message) async {
          calls++;
          return codec.encodeMessage(<Object?>[
            {'sdk': 'GLMap', 'width': 320, 'surfaceAvailable': true, 'taps': 2},
          ]);
        });
        messenger.setMockMessageHandler(
          disposeChannel,
          (_) async => codec.encodeMessage(<Object?>[null]),
        );
        addTearDown(() {
          messenger.setMockMessageHandler(channel, null);
          messenger.setMockMessageHandler(disposeChannel, null);
        });
        expect(await current.diagnostics(), containsPair('taps', 2));
        expect(calls, 1);

        final nativeReply = Completer<ByteData?>();
        messenger.setMockMessageHandler(channel, (_) => nativeReply.future);
        final pending = current.diagnostics();
        final disposed = isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'map_disposed',
        );
        final pendingCheck = expectLater(pending, throwsA(disposed));
        await tester.pumpWidget(const SizedBox());
        await pendingCheck;
        await expectLater(current.diagnostics(), throwsA(disposed));
        nativeReply.complete(
          codec.encodeMessage(<Object?>[
            {'taps': 99},
          ]),
        );
        await tester.pump();
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
