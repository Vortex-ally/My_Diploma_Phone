import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final String status;
  final String? labelOverride;

  const StatusChip({super.key, required this.status, this.labelOverride});

  Color _color() {
    switch (status) {
      case 'apply':
        return const Color(0xFF1976D2); // blue
      case 'pending':
        return const Color(0xFFEF6C00); // orange
      case 'approved':
        return const Color(0xFF2E7D32); // green
      case 'completed':
        return const Color(0xFF6A1B9A); // purple
      case 'rejected':
        return const Color(0xFFC62828); // red
      default:
        return Colors.grey;
    }
  }

  String _label() {
    if (labelOverride != null) return labelOverride!;
    switch (status) {
      case 'apply':
        return 'Доступно';
      case 'pending':
        return 'Очікує';
      case 'approved':
        return 'Схвалено';
      case 'completed':
        return 'Відпрацьовано';
      case 'rejected':
        return 'Відхилено';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        _label(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
