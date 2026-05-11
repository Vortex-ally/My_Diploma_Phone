import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/format.dart';

class OrganizerDashboard extends StatefulWidget {
  const OrganizerDashboard({super.key});

  @override
  State<OrganizerDashboard> createState() => _OrganizerDashboardState();
}

class _OrganizerDashboardState extends State<OrganizerDashboard>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final ApiService _api = ApiService();

  List<Project> _projects = [];
  bool _isLoading = false;
  String? _error;

  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isAuthenticated) {
      _loaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadProjects());
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final projects = await _api.getOrganizerProjects();
      if (mounted) setState(() => _projects = projects);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Організатор'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Мої заходи'),
            Tab(text: 'Статистика'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadProjects,
        child: TabBarView(
          controller: _tabs,
          children: [
            _ProjectsTab(
              projects: _projects,
              isLoading: _isLoading,
              error: _error,
              onRefresh: _loadProjects,
              api: _api,
            ),
            _StatsTab(projects: _projects),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateProjectDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Новий захід'),
      ),
    );
  }

  Future<void> _showCreateProjectDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const _CreateProjectDialog(),
    );
    if (result == true) _loadProjects();
  }
}

class _ProjectsTab extends StatelessWidget {
  final List<Project> projects;
  final bool isLoading;
  final String? error;
  final VoidCallback onRefresh;
  final ApiService api;

  const _ProjectsTab({
    required this.projects,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
    required this.api,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && projects.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && projects.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.error_outline, size: 72, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      );
    }
    if (projects.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          Icon(Icons.event_busy, size: 72, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Ви ще не створили жодного заходу.\nНатисніть «+» щоб додати.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 15),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: projects.length,
      itemBuilder: (context, i) => _OrgProjectCard(
        project: projects[i],
        api: api,
        onChanged: onRefresh,
      ),
    );
  }
}

class _OrgProjectCard extends StatefulWidget {
  final Project project;
  final ApiService api;
  final VoidCallback onChanged;

  const _OrgProjectCard({
    required this.project,
    required this.api,
    required this.onChanged,
  });

  @override
  State<_OrgProjectCard> createState() => _OrgProjectCardState();
}

class _OrgProjectCardState extends State<_OrgProjectCard> {
  bool _expanded = false;
  List<Map<String, dynamic>> _applications = [];
  bool _loadingApps = false;

  Future<void> _loadApplications() async {
    setState(() => _loadingApps = true);
    try {
      final apps = await widget.api.getProjectApplications(widget.project.id);
      if (mounted) setState(() => _applications = apps);
    } catch (_) {}
    if (mounted) setState(() => _loadingApps = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = widget.project;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                if (p.date != null)
                  Text('${formatDate(p.date!)} · ${p.hours} год · ${p.location ?? ''}',
                      style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.people, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${p.currentVolunteers}/${p.maxVolunteers == 0 ? '∞' : p.maxVolunteers}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () {
                setState(() => _expanded = !_expanded);
                if (_expanded && _applications.isEmpty) {
                  _loadApplications();
                }
              },
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            if (_loadingApps)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )
            else if (_applications.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Немає заявок',
                  style: TextStyle(color: Colors.black45),
                ),
              )
            else
              ..._applications.map(
                (app) => _ApplicationTile(
                  app: app,
                  api: widget.api,
                  onUpdated: () {
                    _loadApplications();
                    widget.onChanged();
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ApplicationTile extends StatelessWidget {
  final Map<String, dynamic> app;
  final ApiService api;
  final VoidCallback onUpdated;

  const _ApplicationTile({
    required this.app,
    required this.api,
    required this.onUpdated,
  });

  static Color _statusColor(String s) {
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

  static String _statusLabel(String s) {
    switch (s) {
      case 'pending':
        return 'Очікує';
      case 'approved':
        return 'Схвалено';
      case 'completed':
        return 'Відпрацьовано';
      case 'rejected':
        return 'Відхилено';
      default:
        return s;
    }
  }

  static IconData _statusIcon(String s) {
    switch (s) {
      case 'pending':
        return Icons.hourglass_empty_rounded;
      case 'approved':
        return Icons.check_circle_outline;
      case 'completed':
        return Icons.workspace_premium;
      case 'rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = app['status'] as String;
    final color = _statusColor(status);
    final requestId = app['id'] as int;
    final name = app['volunteer_name'] as String;
    final group = app['group_name'] as String;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withValues(alpha: 0.18),
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      if (group.isNotEmpty)
                        Text(
                          group,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(status), size: 12, color: color),
                      const SizedBox(width: 4),
                      Text(
                        _statusLabel(status),
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (app['approved_hours'] != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time, size: 14, color: Colors.green),
                    const SizedBox(width: 6),
                    Text(
                      'Зараховано годин: ${app['approved_hours']}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (status == 'pending') ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmReject(context, requestId, name),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Відхилити'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _showApproveSheet(context, requestId, name, group),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Схвалити'),
                    ),
                  ),
                ],
              ),
            ] else if (status == 'approved') ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => _showCompleteSheet(context, requestId, name),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.workspace_premium, size: 16),
                  label: const Text('Зарахувати години'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReject(
      BuildContext context, int requestId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Відхилити заявку'),
          ],
        ),
        content: Text('Відхилити заявку від $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Назад'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Відхилити'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await api.updateApplicationStatus(requestId: requestId, status: 'rejected');
      onUpdated();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _showApproveSheet(
      BuildContext context, int requestId, String name, String group) async {
    final hours = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ApproveSheet(name: name, group: group, isComplete: false),
    );
    if (hours == null || !context.mounted) return;
    try {
      await api.updateApplicationStatus(
        requestId: requestId,
        status: 'approved',
        approvedHours: hours,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Заявку схвалено'),
            ]),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
        onUpdated();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _showCompleteSheet(
      BuildContext context, int requestId, String name) async {
    final hours = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ApproveSheet(name: name, group: '', isComplete: true),
    );
    if (hours == null || !context.mounted) return;
    try {
      await api.updateApplicationStatus(
        requestId: requestId,
        status: 'completed',
        approvedHours: hours,
        starRating: true,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.workspace_premium, color: Colors.white),
              SizedBox(width: 8),
              Text('Години зараховано'),
            ]),
            backgroundColor: Color(0xFF6A1B9A),
          ),
        );
        onUpdated();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }
}

class _ApproveSheet extends StatefulWidget {
  final String name;
  final String group;
  final bool isComplete;

  const _ApproveSheet({
    required this.name,
    required this.group,
    required this.isComplete,
  });

  @override
  State<_ApproveSheet> createState() => _ApproveSheetState();
}

class _ApproveSheetState extends State<_ApproveSheet> {
  int _hours = 4;
  final _quickValues = [1, 2, 3, 4, 6, 8];

  @override
  Widget build(BuildContext context) {
    final primary = widget.isComplete
        ? const Color(0xFF6A1B9A)
        : const Color(0xFF2E7D32);
    final icon = widget.isComplete
        ? Icons.workspace_premium
        : Icons.check_circle_outline;
    final title = widget.isComplete ? 'Зарахувати години' : 'Схвалити заявку';
    final btnLabel = widget.isComplete ? 'Зарахувати' : 'Схвалити';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: primary, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Volunteer info card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: primary.withValues(alpha: 0.18),
                  child: Text(
                    widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (widget.group.isNotEmpty)
                      Text(
                        widget.group,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Hours label
          Row(
            children: [
              const Icon(Icons.access_time, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              const Text(
                'Кількість годин',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                '$_hours год',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Quick select chips
          Row(
            children: _quickValues.map((v) {
              final selected = v == _hours;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () => setState(() => _hours = v),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? primary
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? primary : Colors.grey.shade300,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$v',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: selected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // +/- stepper row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.outlined(
                onPressed: _hours > 1 ? () => setState(() => _hours--) : null,
                icon: const Icon(Icons.remove),
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  '$_hours',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
              ),
              IconButton.outlined(
                onPressed: () => setState(() => _hours++),
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Скасувати'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, _hours),
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(icon, size: 18),
                  label: Text(btnLabel, style: const TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsTab extends StatelessWidget {
  final List<Project> projects;
  const _StatsTab({required this.projects});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = projects.length;
    final totalVolunteers = projects.fold<int>(0, (s, p) => s + p.currentVolunteers);

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _StatCard(
          icon: Icons.event,
          label: 'Всього заходів',
          value: '$total',
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 12),
        _StatCard(
          icon: Icons.people,
          label: 'Учасників загалом',
          value: '$totalVolunteers',
          color: Colors.teal,
        ),
        const SizedBox(height: 12),
        _StatCard(
          icon: Icons.access_time,
          label: 'Всього годин',
          value: '${projects.fold<int>(0, (s, p) => s + (p.hours * p.currentVolunteers))}',
          color: Colors.orange,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(label, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateProjectDialog extends StatefulWidget {
  const _CreateProjectDialog();

  @override
  State<_CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<_CreateProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController(text: '4');
  final _maxCtrl = TextEditingController(text: '10');
  DateTime _date = DateTime.now().add(const Duration(days: 7));
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _hoursCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ApiService().createProject(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        date: _date,
        hours: int.tryParse(_hoursCtrl.text) ?? 4,
        maxVolunteers: int.tryParse(_maxCtrl.text) ?? 0,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новий захід'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Назва *', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Обов\'язкове поле' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Опис', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationCtrl,
                decoration: const InputDecoration(labelText: 'Місце *', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Обов\'язкове поле' : null,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(formatDate(_date)),
                subtitle: const Text('Дата заходу'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _hoursCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Годин', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _maxCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Макс. волонтерів (0=∞)', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Скасувати'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Створити'),
        ),
      ],
    );
  }
}
