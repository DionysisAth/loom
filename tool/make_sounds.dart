// Synthesises the plucked-yarn sounds into assets/audio/ (Karplus-Strong).
//
//   dart run tool/make_sounds.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int rate = 44100;

void main() {
  Directory('assets/audio').createSync(recursive: true);
  // A rising major pentatonic, one note per cell the thread enters.
  const notes = [
    392.00, 440.00, 523.25, 587.33, 659.25, 783.99, //
    880.00, 1046.50, 1174.66, 1318.51, 1567.98, 1760.00,
  ];
  for (var i = 0; i < notes.length; i++) {
    final s = pluck(notes[i], 0.45, seed: i, brightness: 0.55, decay: 0.994);
    write(
      'assets/audio/pluck_${i.toString().padLeft(2, '0')}.wav',
      s,
      gain: 0.5,
    );
  }
  // A deeper note when a thread reaches its twin knot.
  final knot = mix([
    pluck(196.00, 0.9, seed: 40, brightness: 0.4, decay: 0.997),
    pluck(392.00, 0.9, seed: 41, brightness: 0.3, decay: 0.996),
  ]);
  write('assets/audio/knot.wav', knot, gain: 0.7);
  // A soft strum as the threads tighten and the hoop clears.
  final chord = [261.63, 329.63, 392.00, 523.25, 659.25, 783.99];
  final strum = mix([
    for (var i = 0; i < chord.length; i++)
      delay(
        pluck(chord[i], 1.6, seed: 60 + i, brightness: 0.45, decay: 0.998),
        0.045 * i,
      ),
  ]);
  write('assets/audio/clear.wav', strum, gain: 0.8);
  // A small bell for hints.
  write('assets/audio/hint.wav', bell([1318.51, 1975.53], 0.9), gain: 0.35);
}

Float64List pluck(
  double freq,
  double seconds, {
  required int seed,
  double brightness = 0.5,
  double decay = 0.996,
}) {
  final n = (rate * seconds).round();
  final out = Float64List(n);
  final period = rate / freq;
  final len = period.floor();
  final frac = period - len;
  final buf = Float64List(len + 2);
  final rng = Random(seed);
  // Softened noise burst: lower brightness means a rounder, woollier tone.
  var prev = 0.0;
  for (var i = 0; i < buf.length; i++) {
    final white = rng.nextDouble() * 2 - 1;
    prev = prev + brightness * (white - prev);
    buf[i] = prev;
  }
  var idx = 0;
  for (var i = 0; i < n; i++) {
    final a = buf[idx % buf.length];
    final b = buf[(idx + 1) % buf.length];
    final v =
        decay * ((1 - frac * 0.5) * a + frac * 0.5 * b) * 0.5 + decay * 0.5 * b;
    out[i] = a;
    buf[idx % buf.length] = v;
    idx++;
  }
  // Gentle attack and a fade at the end so nothing clicks.
  final attack = (rate * 0.002).round();
  final fade = (rate * 0.08).round();
  for (var i = 0; i < n; i++) {
    var g = 1.0;
    if (i < attack) g = i / attack;
    if (i > n - fade) g *= (n - i) / fade;
    out[i] *= g;
  }
  return out;
}

Float64List bell(List<double> freqs, double seconds) {
  final n = (rate * seconds).round();
  final out = Float64List(n);
  for (var f = 0; f < freqs.length; f++) {
    for (var i = 0; i < n; i++) {
      final t = i / rate;
      out[i] += sin(2 * pi * freqs[f] * t) * exp(-t * (4 + 2 * f)) / (f + 1);
    }
  }
  final attack = (rate * 0.004).round();
  for (var i = 0; i < attack; i++) {
    out[i] *= i / attack;
  }
  return out;
}

Float64List delay(Float64List s, double seconds) {
  final d = (rate * seconds).round();
  return Float64List(s.length + d)..setRange(d, d + s.length, s);
}

Float64List mix(List<Float64List> parts) {
  final n = parts.map((p) => p.length).reduce(max);
  final out = Float64List(n);
  for (final p in parts) {
    for (var i = 0; i < p.length; i++) {
      out[i] += p[i];
    }
  }
  return out;
}

void write(String path, Float64List s, {double gain = 0.6}) {
  var peak = 1e-9;
  for (final v in s) {
    peak = max(peak, v.abs());
  }
  final pcm = Int16List(s.length);
  for (var i = 0; i < s.length; i++) {
    pcm[i] = (s[i] / peak * gain * 32767).round().clamp(-32768, 32767);
  }
  final data = pcm.buffer.asUint8List();
  final header = ByteData(44);
  void str(int o, String v) {
    for (var i = 0; i < 4; i++) {
      header.setUint8(o + i, v.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  header.setUint32(4, 36 + data.length, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, 1, Endian.little); // mono
  header.setUint32(24, rate, Endian.little);
  header.setUint32(28, rate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  str(36, 'data');
  header.setUint32(40, data.length, Endian.little);
  File(path).writeAsBytesSync([...header.buffer.asUint8List(), ...data]);
}
