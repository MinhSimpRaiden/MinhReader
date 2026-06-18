String formatVietnameseDateTime(DateTime? value) {
  if (value == null) return 'Chưa đọc';
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)} ${two(value.day)}/${two(value.month)}/${value.year}';
}
