import 'dart:async';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';
import 'package:flutter_sanity_mcp/flutter_sanity_mcp.dart';

void main() {
  group('FlutterSanityServer MCP Protocol', () {
    test('Server initializes with correct metadata and registered tools',
        () async {
      final inController = StreamController<String>();
      final outController = StreamController<String>();
      // Drain outController so sink writes don't hang
      outController.stream.listen((_) {});

      final serverChannel =
          StreamChannel<String>(inController.stream, outController.sink);
      final customBreaker = LoopBreaker();
      final server =
          FlutterSanityServer(serverChannel, loopBreaker: customBreaker);

      expect(server.implementation.name, equals('flutter-sanity-mcp'));
      expect(server.implementation.version, equals('1.0.0'));
      expect(server.loopBreaker, equals(customBreaker));

      await inController.close();
      await server.shutdown();
      await outController.close();
    });

    test('LoopBreaker state is tracked by get_sanity_health', () async {
      final inController = StreamController<String>();
      final outController = StreamController<String>();
      outController.stream.listen((_) {});

      final serverChannel =
          StreamChannel<String>(inController.stream, outController.sink);
      final breaker = LoopBreaker();
      final server = FlutterSanityServer(serverChannel, loopBreaker: breaker);

      // Simulate a failure in breaker
      final decision = breaker.processOutput(
        'RenderFlex overflowed by 35.0 pixels on the bottom\nlib/screens/home.dart:45',
      );
      expect(decision.level, equals(BreakerLevel.normal));
      expect(breaker.consecutiveFailures, equals(1));

      // Second failure escalates to guardrail
      final decision2 = breaker.processOutput(
        'RenderFlex overflowed by 35.0 pixels on the bottom\nlib/screens/home.dart:45',
      );
      expect(decision2.level, equals(BreakerLevel.guardrailWarning));
      expect(decision2.banner, contains('[GUARDRAIL_WARNING]'));

      // Third failure trips circuit breaker
      final decision3 = breaker.processOutput(
        'RenderFlex overflowed by 35.0 pixels on the bottom\nlib/screens/home.dart:45',
      );
      expect(decision3.level, equals(BreakerLevel.circuitBreakerTripped));
      expect(decision3.banner, contains('[CIRCUIT_BREAKER_TRIPPED]'));

      await inController.close();
      await server.shutdown();
      await outController.close();
    });
  });
}
