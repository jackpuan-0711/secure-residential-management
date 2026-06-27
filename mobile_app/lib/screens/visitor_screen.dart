import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../features/visitor/domain/visitor_invitation.dart';
import '../models/app_user.dart';
import '../services/visitor_repository.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'pre_register_visitor_screen.dart';

/// Resident-facing visitor management: issue a pre-registered visitor pass,
/// see the live list of passes you've issued (with their lifecycle status),
/// show a pass's QR for the gate, and cancel a pass that's no longer needed.
///
/// The QR encodes ONLY [VisitorInvitation.qrPayload] — the opaque capability
/// token, never visitor PII (CWE-200/CWE-359). All writes flow through
/// [VisitorRepository], gated server-side by firestore.rules.
class VisitorScreen extends StatefulWidget {
  final AppUser user;

  /// Injectable for tests; defaults to a live [VisitorRepository].
  final VisitorRepository? repository;

  const VisitorScreen({super.key, required this.user, this.repository});

  @override
  State<VisitorScreen> createState() => _VisitorScreenState();
}

class _VisitorScreenState extends State<VisitorScreen> {
  late final VisitorRepository _repo;
  late final Stream<List<VisitorInvitation>> _stream;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? VisitorRepository();
    _stream = _repo.watchMyInvitations(widget.user.uid);
  }

  bool get _canIssue => (widget.user.unitNumber ?? '').isNotEmpty;

  Future<void> _openComposer() async {
    final posted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PreRegisterVisitorScreen(
          residentId: widget.user.uid,
          unitNumber: widget.user.unitNumber ?? '',
          repository: widget.repository,
        ),
      ),
    );
    if (posted == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Visitor pass issued.')));
    }
  }

  Future<void> _cancel(VisitorInvitation inv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this pass?'),
        content: Text(
          "${inv.visitorName}'s pass will be revoked and can no longer be "
          'used at the gate. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep pass'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel pass'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _repo.cancelInvitation(
        token: inv.invitationId!,
        residentId: widget.user.uid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pass cancelled.')));
    } catch (e) {
      if (!mounted) return;
      final cs = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not cancel: $e'),
          backgroundColor: cs.error,
        ),
      );
    }
  }

  void _showQr(VisitorInvitation inv) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _QrSheet(invitation: inv),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Visitor passes')),
      body: SafeArea(
        child: !_canIssue
            ? _UnverifiedNotice(textTheme: tt, colorScheme: cs)
            : StreamBuilder<List<VisitorInvitation>>(
                stream: _stream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _ErrorState(error: snapshot.error);
                  }
                  final passes = snapshot.data ?? const <VisitorInvitation>[];
                  if (passes.isEmpty) {
                    return const _EmptyState();
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: passes.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _PassCard(
                        invitation: passes[i],
                        onShowQr: () => _showQr(passes[i]),
                        onCancel: () => _cancel(passes[i]),
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: _canIssue
          ? FloatingActionButton.extended(
              onPressed: _openComposer,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('New pass'),
            )
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Pass card
// ─────────────────────────────────────────────────────────────────────────

class _PassCard extends StatelessWidget {
  final VisitorInvitation invitation;
  final VoidCallback onShowQr;
  final VoidCallback onCancel;

  const _PassCard({
    required this.invitation,
    required this.onShowQr,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final (label, color, icon) = _statusVisual(invitation, cs);
    final canPresent =
        invitation.status == VisitorPassStatus.active && !invitation.isExpired;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(invitation.visitorName, style: tt.titleMedium),
                ),
                Icon(icon, size: 16, color: color),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: tt.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            _MetaRow(
              icon: AppIcons.calendar,
              text:
                  '${DateFormat.yMMMEd().format(invitation.visitDate)} · ${invitation.eta}',
            ),
            if (invitation.guestCount > 1) ...[
              const SizedBox(height: AppSpacing.xs),
              _MetaRow(
                icon: Icons.groups_rounded,
                text: '${invitation.guestCount} visitors',
              ),
            ],
            if ((invitation.vehiclePlate ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              _MetaRow(
                icon: Icons.directions_car_rounded,
                text: invitation.vehiclePlate!,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                if (canPresent)
                  FilledButton.tonalIcon(
                    onPressed: onShowQr,
                    icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                    label: const Text('Show QR'),
                  )
                else
                  Text(
                    invitation.status == VisitorPassStatus.active
                        ? 'Expired'
                        : 'Not usable',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                const Spacer(),
                if (invitation.status == VisitorPassStatus.active &&
                    !invitation.isExpired)
                  TextButton(
                    onPressed: onCancel,
                    child: Text('Cancel', style: TextStyle(color: cs.error)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// QR bottom sheet
// ─────────────────────────────────────────────────────────────────────────

class _QrSheet extends StatelessWidget {
  final VisitorInvitation invitation;

  const _QrSheet({required this.invitation});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final canPresent =
        invitation.status == VisitorPassStatus.active && !invitation.isExpired;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(invitation.visitorName, style: tt.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Unit ${invitation.unitNumber} · '
            '${DateFormat.yMMMEd().format(invitation.visitDate)} · '
            '${invitation.eta} · '
            '${invitation.guestCount} visitor${invitation.guestCount == 1 ? '' : 's'}',
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (canPresent)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.lgBr,
                border: Border.all(color: cs.outlineVariant),
              ),
              child: QrImageView(
                data: invitation.qrPayload,
                version: QrVersions.auto,
                size: 220,
                gapless: false,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Column(
                children: [
                  Icon(AppIcons.error, size: 48, color: cs.error),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'This pass is no longer valid.',
                    style: tt.bodyMedium?.copyWith(color: cs.error),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Present this code at the gate. Valid through '
            '${DateFormat.yMMMEd().format(invitation.expiresAt)}.',
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          if (canPresent) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: invitation.qrPayload),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Pass code copied. Share it only with the gate.',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy pass code'),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// States & helpers
// ─────────────────────────────────────────────────────────────────────────

/// Status → (label, colour, icon). Status colours are the project's documented
/// exception to "colours come from Theme.colorScheme" (see AnnouncementsFeed).
(String, Color, IconData) _statusVisual(
  VisitorInvitation invitation,
  ColorScheme cs,
) {
  if (invitation.isUpcoming) {
    return ('Scheduled', cs.tertiary, Icons.event_rounded);
  }
  if (invitation.isExpired) {
    return ('Expired', cs.onSurfaceVariant, Icons.timer_off_rounded);
  }
  switch (invitation.status) {
    case VisitorPassStatus.active:
      return ('Active', AppColors.success, AppIcons.checkCircle);
    case VisitorPassStatus.checkedIn:
      return ('Checked in', cs.primary, Icons.login_rounded);
    case VisitorPassStatus.checkedOut:
      return ('Checked out', cs.onSurfaceVariant, Icons.logout_rounded);
    case VisitorPassStatus.expired:
      return ('Expired', cs.onSurfaceVariant, Icons.timer_off_rounded);
    case VisitorPassStatus.cancelled:
      return ('Cancelled', cs.error, AppIcons.close);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.visitorPassOutlined,
              size: 56,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('No visitor passes yet', style: tt.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Tap “New pass” to pre-register a visitor and generate a '
              'gate QR code.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnverifiedNotice extends StatelessWidget {
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  const _UnverifiedNotice({required this.textTheme, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.pending,
              size: 56,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Unit not verified', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Visitor passes are tied to a verified unit. Once your '
              'residency is approved you can issue passes here.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object? error;

  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: cs.error),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Could not load passes.',
              style: tt.bodyMedium?.copyWith(color: cs.error),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
