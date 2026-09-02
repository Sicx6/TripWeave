int? parseMoneyToCents(String input) {
  final value = input.trim();
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value)) return null;

  final parts = value.split('.');
  final whole = int.tryParse(parts.first);
  if (whole == null) return null;
  final decimalPart = parts.length == 1 ? '00' : parts[1].padRight(2, '0');
  final cents = int.tryParse(decimalPart);
  if (cents == null) return null;

  return whole * 100 + cents;
}
