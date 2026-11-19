/// [0x03, 0x1e] -> "03 1E"
String toHex(List<int> bytes) => bytes
    .map((b) => b.toRadixString(16).padLeft(2, '0'))
    .join(' ')
    .toUpperCase();

/// "03 1e" / "031E" / "03:1E" -> [0x03, 0x1E]. Throws [FormatException] on bad input.
List<int> fromHex(String input) {
  final clean = input.replaceAll(RegExp(r'[\s:,-]'), '');
  if (clean.isEmpty) throw const FormatException('Empty hex string');
  if (clean.length.isOdd) {
    throw FormatException('Odd number of hex digits', input);
  }
  if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(clean)) {
    throw FormatException('Not a hex string', input);
  }
  return [
    for (var i = 0; i < clean.length; i += 2)
      int.parse(clean.substring(i, i + 2), radix: 16),
  ];
}
