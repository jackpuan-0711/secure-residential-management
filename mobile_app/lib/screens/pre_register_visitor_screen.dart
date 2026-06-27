import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/visitor_repository.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

/// Visitor pre-registration composer — opened from [VisitorScreen].
///
/// ─── SECURITY: WHO ISSUES, AND FOR WHICH UNIT, IS NOT USER INPUT ─────────
/// [residentId] and [unitNumber] are supplied by the caller FROM THE VERIFIED
/// PROFILE (the AppUser the resident home was built from) — never typed by the
/// visitor or the resident. They are forwarded verbatim to
/// [VisitorRepository.createInvitation] so the write matches what the Firestore
/// rule pins to `request.auth.uid` and the profile's `unitNumber`. The
/// client-side length / required checks below mirror the rule's bounds for a
/// friendly pre-check; the rule remains the authoritative gate, so a rejected
/// write surfaces as a snackbar and success is never assumed.
class PreRegisterVisitorScreen extends StatefulWidget {
  final String residentId;
  final String unitNumber;

  /// Injectable for tests; defaults to a live [VisitorRepository].
  final VisitorRepository? repository;

  const PreRegisterVisitorScreen({
    super.key,
    required this.residentId,
    required this.unitNumber,
    this.repository,
  });

  @override
  State<PreRegisterVisitorScreen> createState() =>
      _PreRegisterVisitorScreenState();
}

class _PreRegisterVisitorScreenState extends State<PreRegisterVisitorScreen> {
  // Mirror the firestore.rules bounds.
  static const int _maxName = 100;
  static const int _maxContact = 50;
  static const int _maxPlate = 20;
  static const int _maxGuests = 20;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _guestCountCtrl = TextEditingController(text: '1');
  final _plateCtrl = TextEditingController();
  late final VisitorRepository _repo;

  DateTime _visitDate = DateUtils.dateOnly(DateTime.now());
  TimeOfDay _eta = const TimeOfDay(hour: 18, minute: 0);
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? VisitorRepository();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _guestCountCtrl.dispose();
    _plateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitDate.isBefore(now) ? now : _visitDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _visitDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _eta);
    if (picked != null) setState(() => _eta = picked);
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    // Defensive: this screen is only reachable from a verified resident home,
    // but never issue a pass without an issuer + verified unit.
    if (widget.residentId.isEmpty || widget.unitNumber.isEmpty) {
      _toast('Your unit is not verified yet — cannot issue a pass.',
          isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await _repo.createInvitation(
        residentId: widget.residentId,
        unitNumber: widget.unitNumber,
        visitorName: _nameCtrl.text.trim(),
        visitorContact: _contactCtrl.text.trim(),
        guestCount: int.tryParse(_guestCountCtrl.text.trim()) ?? 1,
        vehiclePlate: _plateCtrl.text.trim(),
        visitDate: _visitDate,
        eta: _eta.format(context),
      );
      if (!mounted) return;
      // Back to the list; its stream surfaces the new pass live (newest first).
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast('Could not register visitor: $e', isError: true);
    }
  }

  void _toast(String text, {bool isError = false}) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? cs.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Pre-register visitor')),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _submitting,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(
                  'Issuing for Unit ${widget.unitNumber}',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _nameCtrl,
                  maxLength: _maxName,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Visitor name',
                    hintText: 'e.g. Jane Tan',
                    prefixIcon: Icon(AppIcons.visitorPass),
                  ),
                  validator: (value) {
                    final t = (value ?? '').trim();
                    if (t.isEmpty) return 'Visitor name is required.';
                    if (t.length > _maxName) {
                      return 'Keep the name to $_maxName characters or fewer.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _contactCtrl,
                  maxLength: _maxContact,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Contact number',
                    hintText: 'e.g. 012-345 6789',
                    prefixIcon: Icon(AppIcons.phone),
                  ),
                  validator: (value) {
                    final t = (value ?? '').trim();
                    if (t.isEmpty) return 'A contact number is required.';
                    if (t.length > _maxContact) return 'Contact is too long.';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _guestCountCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Number of visitors',
                    hintText: '1',
                    prefixIcon: Icon(Icons.groups_rounded),
                  ),
                  validator: (value) {
                    final count = int.tryParse((value ?? '').trim());
                    if (count == null) return 'Enter the number of visitors.';
                    if (count < 1 || count > _maxGuests) {
                      return 'Enter between 1 and $_maxGuests visitors.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _plateCtrl,
                  maxLength: _maxPlate,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle plate (optional)',
                    hintText: 'e.g. WXY 1234',
                    prefixIcon: Icon(Icons.directions_car_rounded),
                  ),
                  validator: (value) {
                    final t = (value ?? '').trim();
                    if (t.length > _maxPlate) return 'Plate is too long.';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                _PickerTile(
                  icon: AppIcons.calendar,
                  label: 'Visit date',
                  value: DateFormat.yMMMEd().format(_visitDate),
                  onTap: _pickDate,
                ),
                const SizedBox(height: AppSpacing.sm),
                _PickerTile(
                  icon: Icons.schedule_rounded,
                  label: 'Expected arrival',
                  value: _eta.format(context),
                  onTap: _pickTime,
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.qr_code_2_rounded),
                  label: Text(_submitting ? 'Issuing…' : 'Issue visitor pass'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A tappable, form-styled row that opens a date / time picker. Kept private to
/// this file — the only screen that needs it.
class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: AppRadius.lgBr,
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(value, style: tt.bodyLarge),
            Icon(AppIcons.arrowRight, size: 14, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
