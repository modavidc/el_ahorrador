/// A recognised line and where it sits in the image.
final class OcrLine {
  const OcrLine(
    this.text, {
    required this.top,
    required this.left,
    required this.height,
  });

  final String text;
  final double top;
  final double left;
  final double height;

  double get centerY => top + height / 2;
}

/// The lines in reading order: rows from top to bottom and, within a row,
/// from left to right. ML Kit returns its blocks in no fixed order, so a
/// boxed message can come before the date above it; receipts are read as
/// they look.
String readingOrder(Iterable<OcrLine> lines) {
  final sorted = [...lines]..sort((a, b) => a.centerY.compareTo(b.centerY));
  final rows = <List<OcrLine>>[];
  for (final line in sorted) {
    final row = rows.isEmpty ? null : rows.last;
    // Same row when the centres are closer than half the shorter line:
    // "S/" and a big "2", or a label and its value.
    if (row != null &&
        (line.centerY - row.first.centerY).abs() <
            0.5 *
                (line.height < row.first.height
                    ? line.height
                    : row.first.height)) {
      row.add(line);
    } else {
      rows.add([line]);
    }
  }
  return [
    for (final row in rows)
      for (final line in row..sort((a, b) => a.left.compareTo(b.left)))
        if (line.text.trim().isNotEmpty) line.text.trim(),
  ].join('\n');
}
