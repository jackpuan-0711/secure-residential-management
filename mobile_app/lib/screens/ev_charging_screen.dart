import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_user.dart';
import '../models/ev_session.dart';
import '../models/ev_station.dart';
import '../services/ev_charging_repository.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

/// Resident-facing EV charging: see every bay's live state, start a session on
/// an available bay, stop your own, and review your charging history.
///
/// Bay state is read straight from the authoritative `EvStation.status` (a
/// resident never infers it from other people's sessions). Start / stop go
/// through [EvChargingRepository] transactions, gated server-side by
/// firestore.rules.
class EvChargingScreen extends StatefulWidget {
  final AppUser user;

  /// Injectable for tests; defaults to a live [EvChargingRepository].
  final EvChargingRepository? repository;

  const EvChargingScreen({super.key, required this.user, this.repository});

  @override
  State<EvChargingScreen> createState() => _EvChargingScreenState();
}

class _EvChargingScreenState extends State<EvChargingScreen> {
  late final EvChargingRepository _repo;
  late final Stream<List<EvStation>> _stations;
  late final Stream<List<EvSession>> _mySessions;
  final Map<String, Stream<EvDeviceStatus?>> _deviceStatusStreams = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? EvChargingRepository();
    _stations = _repo.watchStations();
    _mySessions = _repo.watchMySessions(widget.user.uid);
  }

  bool get _canCharge => (widget.user.unitNumber ?? '').isNotEmpty;

  Stream<EvDeviceStatus?> _deviceStatusFor(String stationId) {
    return _deviceStatusStreams.putIfAbsent(
      stationId,
      () => _repo.watchDeviceStatus(stationId),
    );
  }

  Future<void> _start(EvStation station, EvSession? myActive) async {
    if (_busy) return;
    if (myActive != null) {
      _toast('You already have a charging session in progress.');
      return;
    }
    setState(() => _busy = true);
    try {
      await _repo.startCharging(
        stationId: station.id,
        userId: widget.user.uid,
        unitNumber: widget.user.unitNumber ?? '',
      );
      if (mounted) _toast('Charging started at ${station.name}.');
    } catch (e) {
      if (mounted) _toast('Could not start: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop(EvStation station) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _repo.stopCharging(stationId: station.id, userId: widget.user.uid);
      if (mounted) _toast('Charging stopped.');
    } catch (e) {
      if (mounted) _toast('Could not stop: $e', isError: true);
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
    return Scaffold(
      appBar: AppBar(title: const Text('EV Charging')),
      body: SafeArea(
        child: !_canCharge
            ? const _Centered(
                icon: AppIcons.pending,
                title: 'Unit not verified',
                body:
                    'EV charging is available to verified residents. Once '
                    'your residency is approved you can charge here.',
              )
            : StreamBuilder<List<EvStation>>(
                stream: _stations,
                builder: (context, stationSnap) {
                  if (stationSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (stationSnap.hasError) {
                    return _Centered(
                      icon: Icons.error_outline,
                      title: 'Could not load stations',
                      body: '${stationSnap.error}',
                      isError: true,
                    );
                  }
                  final stations = stationSnap.data ?? const <EvStation>[];

                  // Overlay my sessions so the bay I occupy shows "Stop" and the
                  // history list can render.
                  return StreamBuilder<List<EvSession>>(
                    stream: _mySessions,
                    builder: (context, sessionSnap) {
                      final sessions = sessionSnap.data ?? const <EvSession>[];
                      EvSession? myActive;
                      for (final s in sessions) {
                        if (s.status == EvSessionStatus.active) {
                          myActive = s;
                          break;
                        }
                      }
                      return _buildBody(stations, sessions, myActive);
                    },
                  );
                },
              ),
      ),
    );
  }

  Widget _buildBody(
    List<EvStation> stations,
    List<EvSession> sessions,
    EvSession? myActive,
  ) {
    final tt = Theme.of(context).textTheme;
    final history = sessions
        .where((s) => s.status == EvSessionStatus.completed)
        .take(10)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.sm,
          ),
          child: Text('Stations', style: tt.titleMedium),
        ),
        if (stations.isEmpty)
          const _Centered(
            icon: AppIcons.evChargingOutlined,
            title: 'No stations yet',
            body:
                'Charging stations will appear here once management adds '
                'them.',
            embedded: true,
          )
        else
          for (final station in stations)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _StationCard(
                station: station,
                deviceStatus: _deviceStatusFor(station.id),
                isMine: myActive != null && myActive.stationId == station.id,
                busy: _busy,
                onStart: () => _start(station, myActive),
                onStop: () => _stop(station),
              ),
            ),
        if (history.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            child: Text('Recent sessions', style: tt.titleMedium),
          ),
          for (final s in history) _SessionTile(session: s, stations: stations),
        ],
      ],
    );
  }
}

class _StationCard extends StatelessWidget {
  final EvStation station;
  final Stream<EvDeviceStatus?> deviceStatus;
  final bool isMine;
  final bool busy;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _StationCard({
    required this.station,
    required this.deviceStatus,
    required this.isMine,
    required this.busy,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final (statusLabel, statusColor) = _stationVisual(
      station.status,
      isMine,
      cs,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(AppIcons.evCharging, size: 36, color: statusColor),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(station.name, style: tt.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    station.location,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Icon(Icons.circle, size: 10, color: statusColor),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        statusLabel,
                        style: tt.labelMedium?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _DeviceStatusLine(stream: deviceStatus),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _action(context),
          ],
        ),
      ),
    );
  }

  Widget _action(BuildContext context) {
    if (isMine) {
      return FilledButton.tonal(
        onPressed: busy ? null : onStop,
        child: const Text('Stop'),
      );
    }
    if (station.status == EvStationStatus.available) {
      return FilledButton(
        onPressed: busy ? null : onStart,
        child: const Text('Start'),
      );
    }
    return const SizedBox.shrink();
  }
}

class _DeviceStatusLine extends StatelessWidget {
  final Stream<EvDeviceStatus?> stream;

  const _DeviceStatusLine({required this.stream});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return StreamBuilder<EvDeviceStatus?>(
      stream: stream,
      builder: (context, snapshot) {
        final status = snapshot.data;
        final (label, color) = switch (status) {
          EvDeviceStatus(online: true, state: EvDeviceState.charging) => (
            'Device: Charging',
            AppColors.success,
          ),
          EvDeviceStatus(online: true, state: EvDeviceState.idle) => (
            'Device: Idle',
            cs.onSurfaceVariant,
          ),
          EvDeviceStatus(online: true) => (
            'Device: Unknown',
            cs.onSurfaceVariant,
          ),
          _ => ('Device: No signal', cs.error),
        };

        return Row(
          children: [
            Icon(Icons.sensors, size: 14, color: color),
            const SizedBox(width: AppSpacing.xs),
            Text(label, style: tt.bodySmall?.copyWith(color: color)),
          ],
        );
      },
    );
  }
}

class _SessionTile extends StatelessWidget {
  final EvSession session;
  final List<EvStation> stations;

  const _SessionTile({required this.session, required this.stations});

  String get _stationName {
    for (final s in stations) {
      if (s.id == session.stationId) return s.name;
    }
    return 'Station';
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      leading: Icon(AppIcons.evChargingOutlined, color: cs.onSurfaceVariant),
      title: Text(_stationName, style: tt.bodyLarge),
      subtitle: Text(
        DateFormat.yMMMd().add_jm().format(session.startedAt),
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: Text(
        _fmtDuration(session.duration),
        style: tt.labelLarge?.copyWith(color: cs.primary),
      ),
    );
  }
}

/// Station status → (label, colour), from the resident's point of view (their
/// own in-use bay reads "Charging"). Status colours are the documented theme
/// exception (see AnnouncementsFeed).
(String, Color) _stationVisual(EvStationStatus s, bool isMine, ColorScheme cs) {
  switch (s) {
    case EvStationStatus.available:
      return ('Available', AppColors.success);
    case EvStationStatus.inUse:
      return (isMine ? 'Charging — yours' : 'In use', cs.primary);
    case EvStationStatus.offline:
      return ('Out of service', cs.onSurfaceVariant);
  }
}

class _Centered extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final bool isError;
  final bool embedded;

  const _Centered({
    required this.icon,
    required this.title,
    required this.body,
    this.isError = false,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 56, color: isError ? cs.error : cs.onSurfaceVariant),
        const SizedBox(height: AppSpacing.md),
        Text(title, style: tt.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          body,
          textAlign: TextAlign.center,
          style: tt.bodyMedium?.copyWith(
            color: isError ? cs.error : cs.onSurfaceVariant,
          ),
        ),
      ],
    );
    if (embedded) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: content,
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: content,
      ),
    );
  }
}
