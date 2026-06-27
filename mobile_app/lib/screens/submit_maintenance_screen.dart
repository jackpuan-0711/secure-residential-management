import 'package:flutter/material.dart';

import '../models/maintenance_request.dart';
import '../services/maintenance_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/maintenance_visuals.dart';

/// Maintenance request composer — opened from [MaintenanceScreen].
///
/// ─── SECURITY: WHO FILES, AND FOR WHICH UNIT, IS NOT USER INPUT ──────────
/// [residentId] / [unitNumber] come from the verified profile (the AppUser the
/// resident home was built from), never typed by the user. They are forwarded
/// to [MaintenanceRepository.createRequest] so the write matches what the rule
/// pins to `request.auth.uid` and the profile's `unitNumber`. The length checks
/// below mirror the rule's bounds as a friendly pre-check; the rule is the
/// authoritative gate, so a rejected write surfaces and success is never assumed.
class SubmitMaintenanceScreen extends StatefulWidget {
  final String residentId;
  final String unitNumber;

  /// Injectable for tests; defaults to a live [MaintenanceRepository].
  final MaintenanceRepository? repository;

  const SubmitMaintenanceScreen({
    super.key,
    required this.residentId,
    required this.unitNumber,
    this.repository,
  });

  @override
  State<SubmitMaintenanceScreen> createState() =>
      _SubmitMaintenanceScreenState();
}

class _SubmitMaintenanceScreenState extends State<SubmitMaintenanceScreen> {
  // Mirror the firestore.rules bounds.
  static const int _maxTitle = 120;
  static const int _maxDescription = 2000;

  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  late final MaintenanceRepository _repo;

  MaintenanceCategory _category = MaintenanceCategory.plumbing;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? MaintenanceRepository();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    if (widget.residentId.isEmpty || widget.unitNumber.isEmpty) {
      _toast('Your unit is not verified yet — cannot file a request.',
          isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await _repo.createRequest(
        residentId: widget.residentId,
        unitNumber: widget.unitNumber,
        category: _category,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast('Could not submit request: $e', isError: true);
    }
  }

  void _toast(String text, {bool isError = false}) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: isError ? cs.error : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('New maintenance request')),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _submitting,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(
                  'Filing for Unit ${widget.unitNumber}',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<MaintenanceCategory>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final c in MaintenanceCategory.values)
                      DropdownMenuItem(
                        value: c,
                        child: Builder(builder: (_) {
                          final (label, icon) = maintenanceCategoryVisual(c);
                          return Row(
                            children: [
                              Icon(icon, size: 18, color: cs.onSurfaceVariant),
                              const SizedBox(width: AppSpacing.sm),
                              Text(label),
                            ],
                          );
                        }),
                      ),
                  ],
                  onChanged: (v) =>
                      setState(() => _category = v ?? _category),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _titleCtrl,
                  maxLength: _maxTitle,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. Kitchen tap is leaking',
                  ),
                  validator: (value) {
                    final t = (value ?? '').trim();
                    if (t.isEmpty) return 'A short title is required.';
                    if (t.length > _maxTitle) return 'Title is too long.';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _descCtrl,
                  maxLength: _maxDescription,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Describe the issue, where it is, and when it '
                        'started.',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    final t = (value ?? '').trim();
                    if (t.isEmpty) return 'A description is required.';
                    if (t.length > _maxDescription) {
                      return 'Description is too long.';
                    }
                    return null;
                  },
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
                      : const Icon(Icons.send_rounded),
                  label: Text(_submitting ? 'Submitting…' : 'Submit request'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
