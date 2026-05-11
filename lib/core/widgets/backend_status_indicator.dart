import 'package:flutter/material.dart';

import '../../services/backend_warmup.dart';

class BackendStatusIndicator extends StatefulWidget {
  const BackendStatusIndicator({super.key, this.showLabel = true});

  final bool showLabel;

  @override
  State<BackendStatusIndicator> createState() => _BackendStatusIndicatorState();
}

class _BackendStatusIndicatorState extends State<BackendStatusIndicator> {
  bool _warming = false;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _warmUp();
  }

  Future<void> _warmUp({bool force = false}) async {
    if (_warming) {
      return;
    }

    setState(() {
      _warming = true;
      _error = null;
    });

    try {
      await BackendWarmup.instance.ensureWarm(force: force);
      if (!mounted) {
        return;
      }
      setState(() {
        _ready = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _ready = false;
        _error = _formatError(error);
      });
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _warming = false;
      });
    }
  }

  String _formatError(Object error) {
    if (error is StateError) {
      return error.message;
    }
    final message = error.toString();
    return message.replaceFirst('Exception: ', '').trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color color;
    String label;

    if (_error != null) {
      color = theme.colorScheme.error;
      label = 'Error';
    } else if (_warming) {
      color = Colors.amber;
      label = 'Warming';
    } else if (_ready) {
      color = theme.colorScheme.primary;
      label = 'Ready';
    } else {
      color = Colors.amber;
      label = 'Starting';
    }

    final indicator = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        indicator,
        if (widget.showLabel) ...[
          const SizedBox(width: 6),
          Text('Server $label', style: theme.textTheme.bodySmall),
        ],
      ],
    );

    final wrapped = InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _error != null ? () => _warmUp(force: true) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: content,
      ),
    );

    if (_error != null) {
      return Tooltip(message: _error!, child: wrapped);
    }

    return wrapped;
  }
}
