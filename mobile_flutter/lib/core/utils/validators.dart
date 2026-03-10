/// Form validator functions for use with Flutter's [TextFormField.validator].
///
/// Each function returns `null` on valid input, or an error string.
library validators;

/// Required / non-empty
String? requiredField(String? value, {String label = 'This field'}) {
  if (value == null || value.trim().isEmpty) return '$label is required';
  return null;
}

/// Indian mobile number — 10 digits, starting with 6-9
String? phoneNumber(String? value) {
  if (value == null || value.trim().isEmpty) return 'Mobile number is required';
  final digits = value.replaceAll(RegExp(r'[\s\-+]'), '');
  if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
    return 'Enter a valid 10-digit mobile number';
  }
  return null;
}

/// Email validation
String? email(String? value) {
  if (value == null || value.trim().isEmpty) return 'Email is required';
  if (!RegExp(r'^[\w+\-]+(\.[\w+\-]+)*@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]{2,}$')
      .hasMatch(value.trim().toLowerCase())) {
    return 'Enter a valid email address';
  }
  return null;
}

/// GSTIN — 15 chars, format: 2-digit state + 10-char PAN + 1 + Z + check digit
String? gstin(String? value) {
  if (value == null || value.trim().isEmpty) return null; // optional field
  final v = value.trim().toUpperCase();
  if (!RegExp(
    r'^[0-3][0-9][A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$',
  ).hasMatch(v)) {
    return 'Enter a valid 15-character GSTIN';
  }
  return null;
}

/// PIN code — 6 digits
String? pinCode(String? value) {
  if (value == null || value.trim().isEmpty) return 'PIN code is required';
  if (!RegExp(r'^\d{6}$').hasMatch(value.trim())) {
    return 'Enter a valid 6-digit PIN code';
  }
  return null;
}

/// Minimum length
String? minLength(String? value, int min, {String label = 'Value'}) {
  if (value == null || value.length < min) {
    return '$label must be at least $min characters';
  }
  return null;
}

/// Positive number (integer or decimal)
String? positiveNumber(String? value, {String label = 'Amount'}) {
  if (value == null || value.trim().isEmpty) return '$label is required';
  final n = num.tryParse(value.trim());
  if (n == null || n <= 0) return 'Enter a valid positive number';
  return null;
}

/// Non-negative integer (for quantities)
String? quantity(String? value) {
  if (value == null || value.trim().isEmpty) return 'Quantity is required';
  final n = int.tryParse(value.trim());
  if (n == null || n < 0) return 'Enter a valid quantity';
  return null;
}
