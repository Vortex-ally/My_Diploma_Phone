import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/project.dart';
import '../../providers/data_provider.dart';
import '../../utils/format.dart';
import '../common/status_chip.dart';

class ProjectCard extends StatelessWidget {
  final Project project;

  const ProjectCard({super.key, required this.project});

  String _statusText() {
    final s = project.applicationStatus;
    if (s == null) {
      return project.isFull ? 'Набір завершено' : 'Доступно';
    }
    switch (s) {
      case 'pending':
        return 'Заявка очікує';
      case 'approved':
        return 'Ви прийняті';
      case 'completed':
        return 'Відпрацьовано';
      case 'rejected':
        return 'Заявку відхилено';
      default:
        return s;
    }
  }

  String _statusKey() {
    if (project.applicationStatus != null) return project.applicationStatus!;
    if (project.isFull) return 'rejected';
    return 'apply';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canApply = project.canApply;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => Navigator.pushNamed(
            context,
            '/project',
            arguments: project,
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        project.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(
                      status: _statusKey(),
                      labelOverride: _statusText(),
                    ),
                  ],
                ),
                if (project.hasPriority)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: const [
                        Icon(Icons.star, color: Colors.amber, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Пріоритетне місце',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (project.description != null &&
                    project.description!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      project.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    _info(
                      Icons.event,
                      project.date != null
                          ? formatDate(project.date!)
                          : 'Дата не вказана',
                    ),
                    _info(Icons.access_time, '${project.hours} год'),
                    if ((project.location ?? '').isNotEmpty)
                      _info(Icons.location_on, project.location!),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Організатор: ${project.organiserName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      '${project.currentVolunteers}/${project.maxVolunteers == 0 ? "∞" : project.maxVolunteers}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                if (canApply) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.send, size: 18),
                      label: const Text('Подати заявку'),
                      onPressed: () => _confirmApply(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmApply(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подати заявку'),
        content: Text('Подати заявку на захід «${project.name}»?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Скасувати'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Підтвердити'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final data = context.read<DataProvider>();
    final ok = await data.applyToProject(project.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Заявку подано' : (data.error ?? 'Не вдалося подати заявку'),
        ),
      ),
    );
  }

  Widget _info(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
