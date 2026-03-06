import 'package:flutter/material.dart';
import '../../domain/entities/model_state.dart';

class StatusIndicator extends StatelessWidget {
  final ModelState modelState;
  final bool showProgress;

  const StatusIndicator({
    super.key,
    required this.modelState,
    this.showProgress = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = _getBackgroundColor(context);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIcon(context),
            const SizedBox(width: 6),
            Text(
              _getStatusText(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: statusColor,
                letterSpacing: 0.3,
              ),
            ),
            if (showProgress && modelState.status == ModelStatus.loading) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
            ],
            if (modelState.status == ModelStatus.loading && modelState.progress > 0) ...[
              const SizedBox(width: 6),
              Text(
                '${(modelState.progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: statusColor.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    final statusColor = _getBackgroundColor(context);
    switch (modelState.status) {
      case ModelStatus.idle:
        return Icon(
          Icons.circle_outlined,
          size: 14,
          color: statusColor,
        );
      case ModelStatus.loading:
        return SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(statusColor),
          ),
        );
      case ModelStatus.ready:
        return Icon(
          Icons.check_circle,
          size: 14,
          color: statusColor,
        );
      case ModelStatus.generating:
        return _PulsingIcon(color: statusColor);
      case ModelStatus.error:
        return Icon(
          Icons.error_outline,
          size: 14,
          color: statusColor,
        );
    }
  }

  Color _getBackgroundColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (modelState.status) {
      case ModelStatus.idle:
        return colorScheme.outline;
      case ModelStatus.loading:
        return colorScheme.tertiary;
      case ModelStatus.ready:
        return colorScheme.primary;
      case ModelStatus.generating:
        return colorScheme.secondary;
      case ModelStatus.error:
        return colorScheme.error;
    }
  }

  String _getStatusText() {
    switch (modelState.status) {
      case ModelStatus.idle:
        return 'No Model';
      case ModelStatus.loading:
        return 'Loading';
      case ModelStatus.ready:
        return 'Ready';
      case ModelStatus.generating:
        return 'Thinking';
      case ModelStatus.error:
        return 'Error';
    }
  }
}

class _PulsingIcon extends StatefulWidget {
  final Color color;

  const _PulsingIcon({required this.color});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Icon(
            Icons.auto_awesome,
            size: 14,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class CompactStatusIndicator extends StatelessWidget {
  final ModelState modelState;

  const CompactStatusIndicator({
    super.key,
    required this.modelState,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = _getColor(colorScheme);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _getText(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor(ColorScheme colorScheme) {
    switch (modelState.status) {
      case ModelStatus.idle:
        return colorScheme.outline;
      case ModelStatus.loading:
        return colorScheme.tertiary;
      case ModelStatus.ready:
        return colorScheme.primary;
      case ModelStatus.generating:
        return colorScheme.secondary;
      case ModelStatus.error:
        return colorScheme.error;
    }
  }

  String _getText() {
    switch (modelState.status) {
      case ModelStatus.idle:
        return 'Offline';
      case ModelStatus.loading:
        return 'Loading';
      case ModelStatus.ready:
        return 'Online';
      case ModelStatus.generating:
        return 'Active';
      case ModelStatus.error:
        return 'Error';
    }
  }
}
