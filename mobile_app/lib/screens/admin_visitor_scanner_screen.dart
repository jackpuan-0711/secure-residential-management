import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../features/visitor/domain/visitor_invitation.dart';
import '../services/visitor_repository.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

/// Gate/admin QR scanner for visitor passes.
///
/// The QR carries only `srm-visitor:<opaque-token>`. After scanning, this screen
/// performs a keyed Firestore read, then allows claim-gated staff/admin users to
/// check the visitor in or out through the status state machine.
class AdminVisitorScannerScreen extends StatefulWidget {
  final String staffId;
  final VisitorRepository? repository;

  const AdminVisitorScannerScreen({
    super.key,
    required this.staffId,
    this.repository,
  });

  @override
  State<AdminVisitorScannerScreen> createState() =>
      _AdminVisitorScannerScreenState();
}

class _AdminVisitorScannerScreenState extends State<AdminVisitorScannerScreen> {
  late final VisitorRepository _repo;
  late final MobileScannerController _scannerController;
  final _manualCodeController = TextEditingController();

  VisitorInvitation? _invitation;
  String? _token;
  String? _error;
  bool _handlingScan = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? VisitorRepository();
    _scannerController = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _manualCodeController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleCapture(BarcodeCapture capture) async {
    if (_handlingScan || _busy) return;
    String? rawValue;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        rawValue = value;
        break;
      }
    }
    if (rawValue == null) return;

    await _loadPass(rawValue, stopCamera: true);
  }

  Future<void> _loadPass(String rawValue, {required bool stopCamera}) async {
    if (_handlingScan || _busy) return;
    final value = rawValue.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Enter a visitor pass code.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _handlingScan = true;
      _error = null;
    });

    try {
      final token = _repo.tokenFromQrPayload(value);
      final invitation = await _repo.getInvitationByToken(token);
      if (!mounted) return;
      if (stopCamera) {
        try {
          await _scannerController.stop();
        } catch (_) {
          // Manual validation must still work when camera startup failed.
        }
      }
      setState(() {
        _token = token;
        _invitation = invitation;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) {
        setState(() => _handlingScan = false);
      }
    }
  }

  Future<void> _rescan() async {
    _manualCodeController.clear();
    setState(() {
      _invitation = null;
      _token = null;
      _error = null;
      _handlingScan = false;
    });
    try {
      await _scannerController.start();
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Camera unavailable. Paste the visitor pass code below.',
        );
      }
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _scannerController.toggleTorch();
    } catch (_) {
      if (mounted) {
        _toast('Torch is not available on this device.', isError: true);
      }
    }
  }

  Future<void> _refreshPass() async {
    final token = _token;
    if (token == null) return;
    final invitation = await _repo.getInvitationByToken(token);
    if (!mounted) return;
    setState(() => _invitation = invitation);
  }

  Future<void> _checkIn() async {
    final token = _token;
    if (token == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _repo.checkInInvitation(token: token, staffId: widget.staffId);
      await _refreshPass();
      if (mounted) _toast('Visitor checked in.');
    } catch (e) {
      if (mounted) _toast('$e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkOut() async {
    final token = _token;
    if (token == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _repo.checkOutInvitation(token: token, staffId: widget.staffId);
      await _refreshPass();
      if (mounted) _toast('Visitor checked out.');
    } catch (e) {
      if (mounted) _toast('$e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
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
    final invitation = _invitation;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan visitor QR'),
        actions: [
          IconButton(
            tooltip: 'Torch',
            onPressed: _toggleTorch,
            icon: const Icon(Icons.flashlight_on_rounded),
          ),
          IconButton(
            tooltip: 'Rescan',
            onPressed: _rescan,
            icon: const Icon(AppIcons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: invitation == null
            ? _buildScanner()
            : _PassResult(
                invitation: invitation,
                busy: _busy,
                onCheckIn: _checkIn,
                onCheckOut: _checkOut,
                onRescan: _rescan,
              ),
      ),
    );
  }

  Widget _buildScanner() {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _scannerController,
                onDetect: _handleCapture,
                errorBuilder: (context, error) => Container(
                  color: cs.surfaceContainerHighest,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.no_photography_rounded,
                        size: 48,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Camera unavailable',
                        style: tt.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Allow camera access or enter the pass code below.',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: AppRadius.lgBr,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Text(
                'Point the camera at a visitor QR code',
                style: tt.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'The pass will appear here for validation and gate action.',
                textAlign: TextAlign.center,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              if (_handlingScan) ...[
                const SizedBox(height: AppSpacing.md),
                const LinearProgressIndicator(),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: tt.bodySmall?.copyWith(color: cs.error),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _manualCodeController,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                onSubmitted: (value) => _loadPass(value, stopCamera: true),
                decoration: InputDecoration(
                  labelText: 'Pass code',
                  hintText: 'Paste srm-visitor:...',
                  prefixIcon: const Icon(Icons.password_rounded),
                  suffixIcon: IconButton(
                    tooltip: 'Validate pass code',
                    onPressed: _handlingScan
                        ? null
                        : () => _loadPass(
                            _manualCodeController.text,
                            stopCamera: true,
                          ),
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PassResult extends StatelessWidget {
  final VisitorInvitation invitation;
  final bool busy;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  final VoidCallback onRescan;

  const _PassResult({
    required this.invitation,
    required this.busy,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.onRescan,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final (label, color, icon) = _statusVisual(invitation, cs);
    final canCheckIn = invitation.isCurrentlyValid;
    final canCheckOut = invitation.status == VisitorPassStatus.checkedIn;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.14),
                      child: Icon(icon, color: color),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(invitation.visitorName, style: tt.titleLarge),
                          const SizedBox(height: 2),
                          Text(
                            label,
                            style: tt.labelMedium?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _DetailRow(
                  icon: AppIcons.unit,
                  label: 'Unit',
                  value: invitation.unitNumber,
                ),
                _DetailRow(
                  icon: AppIcons.phone,
                  label: 'Contact',
                  value: invitation.visitorContact,
                ),
                _DetailRow(
                  icon: Icons.groups_rounded,
                  label: 'Visitors',
                  value:
                      '${invitation.guestCount} visitor${invitation.guestCount == 1 ? '' : 's'}',
                ),
                _DetailRow(
                  icon: AppIcons.calendar,
                  label: 'Expected arrival',
                  value:
                      '${DateFormat.yMMMEd().format(invitation.visitDate)} ${invitation.eta}',
                ),
                if ((invitation.vehiclePlate ?? '').isNotEmpty)
                  _DetailRow(
                    icon: Icons.directions_car_rounded,
                    label: 'Vehicle',
                    value: invitation.vehiclePlate!,
                  ),
                _DetailRow(
                  icon: Icons.timer_rounded,
                  label: 'Valid until',
                  value: DateFormat.yMMMEd().add_jm().format(
                    invitation.expiresAt,
                  ),
                ),
                if (invitation.checkedInAt != null)
                  _DetailRow(
                    icon: Icons.login_rounded,
                    label: 'Checked in',
                    value: DateFormat.yMMMEd().add_jm().format(
                      invitation.checkedInAt!,
                    ),
                  ),
                if (invitation.checkedOutAt != null)
                  _DetailRow(
                    icon: Icons.logout_rounded,
                    label: 'Checked out',
                    value: DateFormat.yMMMEd().add_jm().format(
                      invitation.checkedOutAt!,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (busy) const LinearProgressIndicator(),
        const SizedBox(height: AppSpacing.sm),
        FilledButton.icon(
          onPressed: canCheckIn && !busy ? onCheckIn : null,
          icon: const Icon(Icons.login_rounded),
          label: const Text('Check in'),
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton.tonalIcon(
          onPressed: canCheckOut && !busy ? onCheckOut : null,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Check out'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: busy ? null : onRescan,
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: const Text('Scan another pass'),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                Text(value, style: tt.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
