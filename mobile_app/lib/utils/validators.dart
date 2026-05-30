import 'package:flutter/services.dart';

/// Canonical unit-number format: Block-Floor-Unit.
///   Block: A-C
///   Floor: 1-30
///   Unit:  1-20
/// Valid examples: A-12-5, B-5-10, C-30-20. Numbers are NOT zero-padded
/// (5, not 05) — the pattern rejects leading zeros.
///
/// ─── ONE REGEX, THREE ENFORCEMENT POINTS ───────────────────────────
/// This exact pattern is mirrored in firestore.rules (server-side) and
/// re-checked in UserRepository.applyForResident. Client-side validation
/// is UX only and is NEVER trusted on its own (CWE-20 / CWE-602:
/// improper input validation / client-side enforcement of security).
const String kUnitNumberPattern =
    r'^[A-C]-([1-9]|[12][0-9]|30)-([1-9]|1[0-9]|20)$';

/// Compiled form of [kUnitNumberPattern] for Dart-side checks.
final RegExp unitNumberRegExp = RegExp(kUnitNumberPattern);

/// User-facing format hint. The example is a VALID value under
/// [kUnitNumberPattern].
const String unitNumberError =
    'Format must be Block-Floor-Unit, e.g. A-12-5. '
    'Blocks A-C, floors 1-30, units 1-20.';

/// Short hint for the input field's helper/hint text.
const String unitNumberHint = 'e.g. A-12-5';

/// Validator for a required unit-number field. Returns null when valid,
/// otherwise a user-friendly error message.
String? validateUnitNumber(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return 'Unit number is required';
  if (!unitNumberRegExp.hasMatch(v)) return unitNumberError;
  return null;
}

/// Input formatters for unit-number fields: restrict typing to the legal
/// character set and force uppercase, so 'a-12-5' becomes 'A-12-5' as the
/// user types and stray characters never reach the value.
final List<TextInputFormatter> unitNumberInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[A-Ca-c0-9\-]')),
  TextInputFormatter.withFunction(
    (oldValue, newValue) =>
        newValue.copyWith(text: newValue.text.toUpperCase()),
  ),
];
