import 'package:flutter/material.dart';

import '../models/ev_station.dart';
import '../services/ev_charging_repository.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

class AdminEvStationsScreen extends StatefulWidget {
  final EvChargingRepository? repository;

  const AdminEvStationsScreen({super.key, this.repository});

  @override
  State<AdminEvStationsScreen> createState() => _AdminEvStationsScreenState();
}

class _AdminEvStationsScreenState extends State<AdminEvStationsScreen> {
  late final EvChargingRepository _repo;
  late final Stream<List<EvStation>> _stations;
  final Set<String> _busyStationIds = <String>{};

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? EvChargingRepository();
    _stations = _repo.watchStations();
  }

  bool _isBusy(EvStation station) => _busyStationIds.contains(station.id);

  Future<void> _runStationAction(
    EvStation station,
    Future<void> Function() action,
    String successMessage,
  ) async {
    if (_isBusy(station)) return;
    setState(() => _busyStationIds.add(station.id));
    try {
      await action();
      if (mounted) _toast(successMessage);
    } catch (e) {
      if (mounted) _toast('Station update failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busyStationIds.remove(station.id));
    }
  }

  void _toast(String text, {bool isError = false}) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: isError ? cs.error : null),
    );
  }

  Future<void> _addStation() async {
    final result = await _showStationEditor(
      title: 'Add charging station',
      actionLabel: 'Add station',
    );
    if (result == null) return;

    try {
      await _repo.addStation(name: result.name, location: result.location);
      if (mounted) _toast('Station added.');
    } catch (e) {
      if (mounted) _toast('Could not add station: $e', isError: true);
    }
  }

  Future<void> _editStation(EvStation station) async {
    final result = await _showStationEditor(
      title: 'Edit station',
      actionLabel: 'Save changes',
      initialName: station.name,
      initialLocation: station.location,
    );
    if (result == null) return;

    await _runStationAction(
      station,
      () => _repo.updateStationDetails(
        stationId: station.id,
        name: result.name,
        location: result.location,
      ),
      '${result.name} updated.',
    );
  }

  Future<_StationFormResult?> _showStationEditor({
    required String title,
    required String actionLabel,
    String initialName = '',
    String initialLocation = '',
  }) async {
    final nameCtrl = TextEditingController(text: initialName);
    final locationCtrl = TextEditingController(text: initialLocation);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<_StationFormResult>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                maxLength: 100,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. Station 1',
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Name is required.' : null,
              ),
              TextFormField(
                controller: locationCtrl,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'e.g. Basement 2, Bay A',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop(
                  _StationFormResult(
                    nameCtrl.text.trim(),
                    locationCtrl.text.trim(),
                  ),
                );
              }
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    locationCtrl.dispose();
    return result;
  }

  Future<void> _setOffline(EvStation station, bool offline) async {
    await _runStationAction(
      station,
      () => _repo.setStationOffline(stationId: station.id, offline: offline),
      offline ? '${station.name} is offline.' : '${station.name} is online.',
    );
  }

  Future<void> _endActiveSession(EvStation station) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('End session at ${station.name}?'),
        content: const Text(
          'This closes the active charging session and makes the bay available '
          'again. Use this only when the charger is stuck or a resident needs '
          'management help.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('End session'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _runStationAction(
      station,
      () => _repo.stopStationByAdmin(stationId: station.id),
      '${station.name} session ended.',
    );
  }

  Future<void> _delete(EvStation station) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${station.name}?'),
        content: const Text('This permanently removes the charging station.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _runStationAction(
      station,
      () => _repo.removeStation(station.id),
      '${station.name} removed.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('EV stations')),
      body: SafeArea(
        child: StreamBuilder<List<EvStation>>(
          stream: _stations,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    'Could not load stations.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: tt.bodyMedium?.copyWith(color: cs.error),
                  ),
                ),
              );
            }

            final stations = snapshot.data ?? const <EvStation>[];
            if (stations.isEmpty) {
              return _EmptyStations(onAdd: _addStation);
            }

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                _StationSummary(stations: stations),
                const SizedBox(height: AppSpacing.md),
                for (final station in stations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _AdminStationCard(
                      station: station,
                      busy: _isBusy(station),
                      onEdit: () => _editStation(station),
                      onSetOffline: (off) => _setOffline(station, off),
                      onEndSession: () => _endActiveSession(station),
                      onDelete: () => _delete(station),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addStation,
        icon: const Icon(AppIcons.add),
        label: const Text('Add station'),
      ),
    );
  }
}

class _StationFormResult {
  final String name;
  final String location;

  const _StationFormResult(this.name, this.location);
}

class _StationSummary extends StatelessWidget {
  final List<EvStation> stations;

  const _StationSummary({required this.stations});

  @override
  Widget build(BuildContext context) {
    int count(EvStationStatus status) =>
        stations.where((station) => station.status == status).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _SummaryChip(label: 'Total', value: stations.length.toString()),
            _SummaryChip(
              label: 'Available',
              value: count(EvStationStatus.available).toString(),
            ),
            _SummaryChip(
              label: 'In use',
              value: count(EvStationStatus.inUse).toString(),
            ),
            _SummaryChip(
              label: 'Offline',
              value: count(EvStationStatus.offline).toString(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 112),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: AppRadius.mdBr,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: tt.titleLarge),
          Text(label, style: tt.bodySmall),
        ],
      ),
    );
  }
}

class _AdminStationCard extends StatelessWidget {
  final EvStation station;
  final bool busy;
  final VoidCallback onEdit;
  final ValueChanged<bool> onSetOffline;
  final VoidCallback onEndSession;
  final VoidCallback onDelete;

  const _AdminStationCard({
    required this.station,
    required this.busy,
    required this.onEdit,
    required this.onSetOffline,
    required this.onEndSession,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final inUse = station.status == EvStationStatus.inUse;
    final offline = station.status == EvStationStatus.offline;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(AppIcons.evCharging, size: 32, color: cs.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(station.name, style: tt.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        station.location.isEmpty
                            ? 'Location not set'
                            : station.location,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _StationStatusChip(status: station.status),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (inUse)
                  FilledButton.tonalIcon(
                    onPressed: busy ? null : onEndSession,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('End session'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => onSetOffline(!offline),
                    icon: Icon(
                      offline
                          ? Icons.power_settings_new_rounded
                          : Icons.power_off_rounded,
                    ),
                    label: Text(offline ? 'Set online' : 'Set offline'),
                  ),
                OutlinedButton.icon(
                  onPressed: busy || inUse ? null : onEdit,
                  icon: const Icon(AppIcons.edit),
                  label: const Text('Edit'),
                ),
                OutlinedButton.icon(
                  onPressed: busy || inUse ? null : onDelete,
                  icon: Icon(Icons.delete_outline_rounded, color: cs.error),
                  label: Text('Remove', style: TextStyle(color: cs.error)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StationStatusChip extends StatelessWidget {
  final EvStationStatus status;

  const _StationStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (label, color) = switch (status) {
      EvStationStatus.available => ('Available', AppColors.success),
      EvStationStatus.inUse => ('In use', cs.primary),
      EvStationStatus.offline => ('Offline', cs.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadius.fullBr,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }
}

class _EmptyStations extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyStations({required this.onAdd});

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
              AppIcons.evChargingOutlined,
              size: 56,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('No stations yet', style: tt.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Add charging stations before residents can start EV sessions.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(AppIcons.add),
              label: const Text('Add first station'),
            ),
          ],
        ),
      ),
    );
  }
}
