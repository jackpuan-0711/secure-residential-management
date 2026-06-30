import 'dart:async';

import 'package:flutter/material.dart';

import '../models/ev_station.dart';
import '../theme/app_theme.dart';

class EvDeviceStatusLine extends StatefulWidget {
  final Stream<EvDeviceStatus?> stream;
  final bool prominent;

  const EvDeviceStatusLine({
    super.key,
    required this.stream,
    this.prominent = false,
  });

  @override
  State<EvDeviceStatusLine> createState() => _EvDeviceStatusLineState();
}

class _EvDeviceStatusLineState extends State<EvDeviceStatusLine> {
  late final Timer _freshnessTimer;

  @override
  void initState() {
    super.initState();
    _freshnessTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _freshnessTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return StreamBuilder<EvDeviceStatus?>(
      stream: widget.stream,
      builder: (context, snapshot) {
        final status = snapshot.data;
        final connected = status?.isConnectedAt(DateTime.now()) ?? false;
        final (label, color) = switch ((status, connected)) {
          (EvDeviceStatus(state: EvDeviceState.charging), true) => (
            'Device: Charging',
            AppColors.success,
          ),
          (EvDeviceStatus(state: EvDeviceState.idle), true) => (
            'Device: Idle',
            colors.onSurfaceVariant,
          ),
          (EvDeviceStatus(), true) => (
            'Device: Unknown',
            colors.onSurfaceVariant,
          ),
          _ => ('Device: Not connected', colors.error),
        };

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sensors, size: widget.prominent ? 18 : 14, color: color),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                style:
                    (widget.prominent
                            ? textTheme.titleSmall
                            : textTheme.bodySmall)
                        ?.copyWith(color: color, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }
}
