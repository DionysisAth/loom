// Tuning aid: how often each level slot generates, and why attempts fail.
//
//   dart run tool/probe.dart <seconds> [level ids, comma separated]
import 'dart:io';
import 'dart:math';

import 'package:loom/puzzle/generator.dart';

import 'src/chapters.dart';

void main(List<String> args) {
  final secs = int.parse(args.isEmpty ? '15' : args[0]);
  var id = 0;
  for (final ch in chapters) {
    for (final s in ch.slots) {
      id++;
      if (args.length > 1 && !args[1].split(',').contains('$id')) continue;
      final g = Generator(Random(id));
      final sw = Stopwatch()..start();
      var tries = 0, ok = 0;
      while (sw.elapsed.inSeconds < secs && ok < 3) {
        tries++;
        if (g.attempt(s.spec) != null) ok++;
      }
      stdout.writeln(
        'L$id ${s.role.name} ${s.showpiece ?? ''}: $ok/$tries in ${sw.elapsedMilliseconds}ms ${g.failures}',
      );
    }
  }
}
