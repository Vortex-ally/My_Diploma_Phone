import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/project.dart';
import '../providers/data_provider.dart';
import '../utils/format.dart';
import '../widgets/common/status_chip.dart';

class ProjectDetailScreen extends StatefulWidget {
  final Project project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  late Project _project;
  bool _participantsLoading = false;
  bool _participantsExpanded = false;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final data = context.read<DataProvider>();
      final fresh = await data.fetchProjectDetail(_project.id);
      if (fresh != null && mounted) {
        setState(() => _project = fresh);
      }
    });
  }

  Future<void> _apply() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подати заявку'),
        content: Text('Подати заявку на захід «${_project.name}»?'),
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
    if (confirmed != true || !mounted) return;
    final data = context.read<DataProvider>();
    final ok = await data.applyToProject(_project.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Заявку подано' : (data.error ?? 'Помилка')),
      ),
    );
    if (ok) {
      final fresh = await data.fetchProjectDetail(_project.id);
      if (fresh != null && mounted) {
        setState(() => _project = fresh);
      }
    }
  }

  Future<void> _buyPriority() async {
    final result = await Navigator.pushNamed(
      context,
      '/payment',
      arguments: PaymentArgs(
        planType: 'priority',
        projectId: _project.id,
        projectName: _project.name,
      ),
    );
    if (result == true && mounted) {
      final fresh =
          await context.read<DataProvider>().fetchProjectDetail(_project.id);
      if (fresh != null && mounted) {
        setState(() => _project = fresh);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = _project;

    return Scaffold(
      appBar: AppBar(title: Text(p.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                StatusChip(
                  status: p.applicationStatus ??
                      (p.isFull ? 'rejected' : 'apply'),
                  labelOverride: _statusOverride(p),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (p.hasPriority)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  border: Border.all(color: Colors.amber.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'У вас придбане пріоритетне місце на цей захід',
                      ),
                    ),
                  ],
                ),
              ),
            if ((p.description ?? '').trim().isNotEmpty) ...[
              const Text(
                'Опис',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(p.description!.trim()),
              const SizedBox(height: 18),
            ],
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Tile(
                  icon: Icons.event,
                  label: 'Дата',
                  value: p.date != null ? formatDate(p.date!) : 'Не вказано',
                ),
                _Tile(
                  icon: Icons.access_time,
                  label: 'Години',
                  value: '${p.hours}',
                ),
                _Tile(
                  icon: Icons.location_on,
                  label: 'Місце',
                  value: (p.location ?? '').isEmpty ? 'Не вказано' : p.location!,
                ),
                _Tile(
                  icon: Icons.people,
                  label: 'Учасники',
                  value:
                      '${p.currentVolunteers}/${p.maxVolunteers == 0 ? "∞" : p.maxVolunteers}',
                ),
                _Tile(
                  icon: Icons.person,
                  label: 'Організатор',
                  value: p.organiserName,
                ),
                if (p.price > 0)
                  _Tile(
                    icon: Icons.attach_money,
                    label: 'Вартість',
                    value: '\$${p.price.toStringAsFixed(2)}',
                  ),
              ],
            ),
            const SizedBox(height: 24),
            _buildActions(context),
            const SizedBox(height: 16),
            _ParticipantsSection(
              project: _project,
              isExpanded: _participantsExpanded,
              isLoading: _participantsLoading,
              onToggle: () async {
                if (!_participantsExpanded) {
                  setState(() {
                    _participantsExpanded = true;
                    _participantsLoading = true;
                  });
                  await context.read<DataProvider>().fetchParticipants(_project.id);
                  if (mounted) setState(() => _participantsLoading = false);
                } else {
                  setState(() => _participantsExpanded = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final p = _project;
    final subs = context.read<DataProvider>().subscriptions;
    final children = <Widget>[];

    if (p.applicationStatus == null) {
      if (p.isFull) {
        children.add(_pill(
          color: Colors.red,
          icon: Icons.block,
          text: 'Набір завершено',
        ));
      } else {
        children.add(
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _apply,
              icon: const Icon(Icons.send),
              label: const Text('Подати заявку'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        );
        if (subs.hasPremium) {
          children.add(const SizedBox(height: 10));
          children.add(
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _buyPriority,
                icon: const Icon(Icons.star),
                label: const Text('Купити пріоритетне місце (\$1)'),
              ),
            ),
          );
        } else {
          children.add(const SizedBox(height: 10));
          children.add(
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border.all(color: Colors.amber.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.workspace_premium, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Придбайте Premium (\$20) для доступу до пріоритетних місць',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    } else {
      children.add(_pill(
        color: _statusColor(p.applicationStatus!),
        icon: _statusIcon(p.applicationStatus!),
        text: _statusOverride(p) ?? p.applicationStatus!,
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  Widget _pill({required Color color, required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String? _statusOverride(Project p) {
    final s = p.applicationStatus;
    if (s == null) return p.isFull ? 'Набір завершено' : 'Доступно';
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

  IconData _statusIcon(String s) {
    switch (s) {
      case 'pending':
        return Icons.hourglass_top;
      case 'approved':
        return Icons.check_circle;
      case 'completed':
        return Icons.celebration;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':
        return const Color(0xFFEF6C00);
      case 'approved':
        return const Color(0xFF2E7D32);
      case 'completed':
        return const Color(0xFF6A1B9A);
      case 'rejected':
        return const Color(0xFFC62828);
      default:
        return Colors.grey;
    }
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Tile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade700),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ParticipantsSection extends StatelessWidget {
  final Project project;
  final bool isExpanded;
  final bool isLoading;
  final VoidCallback onToggle;

  const _ParticipantsSection({
    required this.project,
    required this.isExpanded,
    required this.isLoading,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subs = context.watch<DataProvider>().subscriptions;

    if (!subs.hasPremium) {
      return const SizedBox.shrink();
    }

    final cached = context.watch<DataProvider>().participantsCache[project.id];

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.people, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Учасники заходу',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (isLoading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                    ),
                ],
              ),
            ),
          ),
          if (isExpanded && !isLoading) ...[
            const Divider(height: 1),
            if (cached == null || cached.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Підтверджених учасників поки немає',
                  style: TextStyle(color: Colors.black54),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cached.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, indent: 56),
                itemBuilder: (context, i) {
                  final p = cached[i];
                  final name = p['name'] as String? ?? '';
                  final group = p['group'] as String? ?? '';
                  final status = p['status'] as String? ?? '';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.primary,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                      ),
                    ),
                    title: Text(name),
                    subtitle: group.isNotEmpty ? Text(group) : null,
                    trailing: status == 'completed'
                        ? const Icon(Icons.check_circle,
                            color: Colors.green, size: 18)
                        : const Icon(Icons.check_circle_outline,
                            color: Colors.orange, size: 18),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }
}
