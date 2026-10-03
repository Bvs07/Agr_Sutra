import 'dart:typed_data';
 
/// Wraps raw 16-bit PCM audio in a WAV header so the server can read it.
Uint8List pcmToWav(Uint8List pcm, {int sampleRate = 16000, int channels = 1}) {
  final byteRate = sampleRate * channels * 2;
  final header = ByteData(44);
 
  void writeText(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      header.setUint8(offset + i, text.codeUnitAt(i));
    }
  }
 
  writeText(0, 'RIFF');
  header.setUint32(4, 36 + pcm.length, Endian.little);
  writeText(8, 'WAVE');
  writeText(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, channels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, byteRate, Endian.little);
  header.setUint16(32, channels * 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  writeText(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);
 
  final out = Uint8List(44 + pcm.length);
  out.setRange(0, 44, header.buffer.asUint8List());
  out.setRange(44, out.length, pcm);
  return out;
}