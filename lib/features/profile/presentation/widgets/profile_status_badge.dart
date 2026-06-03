import 'package:flutter/material.dart';

/// Badge trạng thái user: active / inactive / pending / suspended.
class ProfileStatusBadge extends StatelessWidget {
  final String? status;
  const ProfileStatusBadge({super.key, this.status});

  ({Color bg, Color fg, IconData icon, String label}) _resolve() {
    switch ((status ?? '').toLowerCase()) {
      case 'active':
        return (
          bg: Colors.green.shade50,
          fg: Colors.green.shade700,
          icon: Icons.verified_rounded,
          label: 'Đang hoạt động',
        );
      case 'inactive':
        return (
          bg: Colors.grey.shade100,
          fg: Colors.grey.shade700,
          icon: Icons.lock_outline_rounded,
          label: 'Tạm khóa',
        );
      case 'pending':
        return (
          bg: Colors.orange.shade50,
          fg: Colors.orange.shade800,
          icon: Icons.hourglass_top_rounded,
          label: 'Chờ kích hoạt',
        );
      case 'suspended':
        return (
          bg: Colors.red.shade50,
          fg: Colors.red.shade700,
          icon: Icons.block_rounded,
          label: 'Đã tạm ngưng',
        );
      default:
        return (
          bg: Colors.grey.shade100,
          fg: Colors.grey.shade700,
          icon: Icons.help_outline_rounded,
          label: 'Không xác định',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _resolve();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: s.fg.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: 13, color: s.fg),
          const SizedBox(width: 5),
          Text(
            s.label,
            style: TextStyle(
              color: s.fg,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
