import 'dart:async';
import 'dart:io' as io;
import 'package:dart_mcp/stdio.dart';
import 'package:flutter_sanity_mcp/flutter_sanity_mcp.dart';

Future<void> main(List<String> args) async {
  // Protect JSON-RPC stdout channel by trapping all print() calls and uncaught errors to stderr
  await runZonedGuarded(
    () async {
      final channel = stdioChannel(
        input: io.stdin,
        output: io.stdout,
      );

      final server = FlutterSanityServer(channel);
      io.stderr.writeln(
          '[flutter-sanity-mcp] Server active and listening on stdio.');
      await server.done;
    },
    (error, stackTrace) {
      io.stderr.writeln('[flutter-sanity-mcp Error] $error\n$stackTrace');
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        // Redirection of all internal print() output to stderr to prevent JSON-RPC corruption
        io.stderr.writeln('[flutter-sanity-mcp] $line');
      },
    ),
  );
}
