import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../main.dart';
import '../models/leaderboard_entry.dart';
import '../models/request.dart';
import '../models/volunteer_goal.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../utils/format.dart';
import '../widgets/cards/project_card.dart';

class VolunteerDashboard extends StatefulWidget {
  const VolunteerDashboard({super.key});

  @override
  State<VolunteerDashboard> createState() => _VolunteerDashboardState();
}

class _VolunteerDashboardState extends State<VolunteerDashboard>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isAuthenticated) {
      _loaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<DataProvider>().loadDashboard();
        context.read<DataProvider>().fetchLeaderboard();
      });
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    final data = context.read<DataProvider>();
    await Future.wait([data.loadDashboard(), data.fetchLeaderboard()]);
    if (!mounted) return;
    await context.read<AuthProvider>().refreshProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Волонтер'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Можливості'),
            Tab(text: 'Мої заявки'),
            Tab(text: 'Розклад'),
            Tab(text: 'Рейтинг'),
            Tab(text: 'Ціль'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: Consumer2<AuthProvider, DataProvider>(
          builder: (context, auth, data, _) {
            return TabBarView(
              controller: _tabs,
              children: [
                _OpportunitiesTab(data: data),
                _ApplicationsTab(data: data),
                _ScheduleTab(data: data),
                _LeaderboardTab(data: data),
                _GoalTab(data: data, auth: auth),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OpportunitiesTab extends StatelessWidget {
  final DataProvider data;
  const _OpportunitiesTab({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isLoading && data.projects.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (data.projects.isEmpty) {
      return _EmptyState(
        icon: Icons.event_busy,
        text: data.error ?? 'Немає доступних заходів',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        for (final p in data.projects) ProjectCard(project: p),
      ],
    );
  }
}

class _ApplicationsTab extends StatelessWidget {
  final DataProvider data;
  const _ApplicationsTab({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isLoading && data.myApplications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final apps = data.myApplications;
    if (apps.isEmpty) {
      return const _EmptyState(
        icon: Icons.assignment_outlined,
        text: 'Ви ще не подали жодної заявки',
      );
    }
    final pending = apps.where((a) => a.isPending).toList();
    final approved = apps.where((a) => a.isApproved).toList();
    final completed = apps.where((a) => a.isCompleted).toList();
    final rejected = apps.where((a) => a.isRejected).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (pending.isNotEmpty)
          _Section(title: 'В очікуванні', children: [
            for (final r in pending) _RequestTile(request: r),
          ]),
        if (approved.isNotEmpty)
          _Section(title: 'Активні участі', children: [
            for (final r in approved) _RequestTile(request: r),
          ]),
        if (completed.isNotEmpty)
          _Section(title: 'Відпрацьовані', children: [
            for (final r in completed) _RequestTile(request: r),
          ]),
        if (rejected.isNotEmpty)
          _Section(title: 'Відхилені', children: [
            for (final r in rejected) _RequestTile(request: r),
          ]),
      ],
    );
  }
}

class _LeaderboardTab extends StatelessWidget {
  final DataProvider data;
  const _LeaderboardTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final entries = data.leaderboard;
    if (entries.isEmpty) {
      if (data.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return const _EmptyState(
        icon: Icons.leaderboard,
        text: 'Поки що немає даних рейтингу',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _LeaderTile(entry: entries[i]),
    );
  }
}

class _GoalTab extends StatelessWidget {
  final DataProvider data;
  final AuthProvider auth;
  const _GoalTab({required this.data, required this.auth});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goal = data.goal;
    final user = auth.user;

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withValues(alpha: 0.75),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Привіт, ${user?.displayName ?? 'волонтер'}!',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                user?.groupName != null && user!.groupName!.isNotEmpty
                    ? 'Група ${user.groupName}'
                    : 'Допомагай — отримуй години',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _GoalCard(goal: goal, onSet: (target) => data.setGoal(targetHours: target)),
        const SizedBox(height: 16),
        _Section(
          title: 'Підписки',
          children: [
            _PremiumTile(
              hasPremium: data.subscriptions.hasPremium,
              hasAnalytics: data.subscriptions.hasAnalytics,
            ),
            const SizedBox(height: 12),
            _AnalyticsTile(
              hasAnalytics: data.subscriptions.hasAnalytics,
              currentHours: data.goal?.currentHours ?? 0,
              totalEvents: auth.stats?.totalEvents ?? 0,
              starCount: auth.stats?.starCount ?? 0,
            ),
          ],
        ),
      ],
    );
  }
}

class _ScheduleTab extends StatefulWidget {
  final DataProvider data;
  const _ScheduleTab({required this.data});

  @override
  State<_ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<_ScheduleTab> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _format = CalendarFormat.month;

  Map<DateTime, List<Request>> _bucketize(List<Request> apps) {
    final map = <DateTime, List<Request>>{};
    for (final r in apps) {
      final date = r.projectDate;
      if (date == null) continue;
      if (r.isRejected) continue;
      final key = DateTime.utc(date.year, date.month, date.day);
      map.putIfAbsent(key, () => []).add(r);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final apps = widget.data.myApplications;
    if (apps.isEmpty) {
      if (widget.data.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return const _EmptyState(
        icon: Icons.calendar_month,
        text: 'Подайте заявку, щоб побачити її у розкладі',
      );
    }
    final events = _bucketize(apps);
    final selected = _selectedDay ?? DateTime.now();
    final selectedKey = DateTime.utc(selected.year, selected.month, selected.day);
    final dayItems = events[selectedKey] ?? const <Request>[];

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Container(
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
          padding: const EdgeInsets.all(8),
          child: TableCalendar<Request>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2035, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) =>
                _selectedDay != null && isSameDay(day, _selectedDay),
            calendarFormat: _format,
            availableCalendarFormats: const {
              CalendarFormat.month: 'Місяць',
              CalendarFormat.twoWeeks: '2 тижні',
              CalendarFormat.week: 'Тиждень',
            },
            startingDayOfWeek: StartingDayOfWeek.monday,
            eventLoader: (day) {
              final key = DateTime.utc(day.year, day.month, day.day);
              return events[key] ?? const <Request>[];
            },
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
            onFormatChanged: (format) => setState(() => _format = format),
            onPageChanged: (focused) => _focusedDay = focused,
            calendarStyle: CalendarStyle(
              markerDecoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Заходи на ${formatDate(selectedKey)}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (dayItems.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'У цей день немає заходів',
              style: TextStyle(color: Colors.black54),
            ),
          )
        else
          ...dayItems.map((r) => _RequestTile(request: r)),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ...children,
        const SizedBox(height: 16),
      ],
    );
  }
}

class _RequestTile extends StatelessWidget {
  final Request request;
  const _RequestTile({required this.request});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(request.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.projectName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (request.starRating)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.star, color: Colors.amber, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (request.projectDate != null)
                _meta(Icons.event, formatDate(request.projectDate!)),
              if (request.projectHours != null)
                _meta(Icons.access_time, '${request.projectHours} год'),
              if ((request.projectLocation ?? '').isNotEmpty)
                _meta(Icons.location_on, request.projectLocation!),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(request.status),
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (request.isCompleted && request.approvedHours != null) ...[
                const SizedBox(width: 8),
                Text(
                  '+${request.approvedHours} год',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const Spacer(),
              if (request.canReview)
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final ok = await Navigator.pushNamed(
                      context,
                      '/review',
                      arguments: request,
                    );
                    if (ok == true && context.mounted) {
                      context.read<DataProvider>().fetchMyApplications();
                    }
                  },
                  icon: const Icon(Icons.rate_review, size: 18),
                  label: const Text('Залишити відгук'),
                ),
            ],
          ),
          if ((request.organizerReport ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.report_outlined, color: Colors.red, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      request.organizerReport!,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  String _statusLabel(String s) {
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

class _LeaderTile extends StatelessWidget {
  final LeaderboardEntry entry;
  const _LeaderTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final highlight = entry.isMe;
    final borderColor = highlight
        ? Theme.of(context).colorScheme.primary
        : Colors.grey.shade300;
    final medal = _medal(entry.rank);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: highlight ? 2 : 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: medal != null
                  ? Text(medal, style: const TextStyle(fontSize: 26))
                  : Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _rankColor(entry.rank).withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${entry.rank}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _rankColor(entry.rank),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.isMe ? '${entry.name} (Ви)' : entry.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if ((entry.groupName ?? '').isNotEmpty)
                  Text(
                    entry.groupName!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${entry.totalHours} год',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String? _medal(int rank) {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return null;
    }
  }

  Color _rankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFD4AC0D);
      case 2:
        return const Color(0xFF7B7B7B);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return Colors.grey;
    }
  }
}

class _GoalCard extends StatelessWidget {
  final VolunteerGoal? goal;
  final Future<bool> Function(int? target) onSet;
  const _GoalCard({required this.goal, required this.onSet});

  @override
  Widget build(BuildContext context) {
    if (goal == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final g = goal!;
    final progress = (g.progressPercentage / 100).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_outlined, color: Colors.deepPurple),
              const SizedBox(width: 8),
              Text(
                g.hasGoal ? 'Ваша ціль' : 'Рекомендована ціль',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              if (g.completed)
                Row(
                  children: const [
                    Icon(Icons.check_circle, color: Colors.green, size: 18),
                    SizedBox(width: 4),
                    Text('Виконано', style: TextStyle(color: Colors.green)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${g.currentHours} / ${g.targetHours} годин',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${g.progressPercentage.toStringAsFixed(0)}% виконано',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final value = await _askTarget(context, g.targetHours);
                    if (value == null) return;
                    final ok = await onSet(value);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok ? 'Ціль оновлено' : 'Не вдалося зберегти ціль',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: Text(g.hasGoal ? 'Змінити ціль' : 'Встановити ціль'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<int?> _askTarget(BuildContext context, int current) async {
    final controller = TextEditingController(text: current.toString());
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ціль годин'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Кількість годин',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Скасувати'),
          ),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(controller.text);
              Navigator.pop(ctx, v);
            },
            child: const Text('Зберегти'),
          ),
        ],
      ),
    );
  }
}

class _PremiumTile extends StatelessWidget {
  final bool hasPremium;
  final bool hasAnalytics;
  const _PremiumTile({required this.hasPremium, required this.hasAnalytics});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium, color: Colors.amber),
              const SizedBox(width: 8),
              const Text(
                'Преміум акаунт',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              if (hasPremium)
                const Chip(
                  label: Text('Активно'),
                  backgroundColor: Color(0xFFE8F5E9),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Розблокуйте список учасників заходів та можливість придбати пріоритетне місце.',
            style: TextStyle(fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          if (!hasPremium)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/payment',
                  arguments: const PaymentArgs(planType: 'premium'),
                ),
                icon: const Icon(Icons.bolt),
                label: const Text('Активувати за \$20'),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnalyticsTile extends StatelessWidget {
  final bool hasAnalytics;
  final int currentHours;
  final int totalEvents;
  final int starCount;

  const _AnalyticsTile({
    required this.hasAnalytics,
    required this.currentHours,
    required this.totalEvents,
    required this.starCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, color: Colors.deepPurple),
              const SizedBox(width: 8),
              const Text(
                'Розширена аналітика',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              if (hasAnalytics)
                const Chip(
                  label: Text('Активно'),
                  backgroundColor: Color(0xFFE8F5E9),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasAnalytics) ...[
            const Text(
              'Ваша статистика',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _AnalyticsStat(
                    label: 'Годин',
                    value: '$currentHours',
                    icon: Icons.access_time,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AnalyticsStat(
                    label: 'Заходів',
                    value: '$totalEvents',
                    icon: Icons.event_available,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AnalyticsStat(
                    label: 'Зірок',
                    value: '$starCount',
                    icon: Icons.star,
                    color: Colors.amber.shade700,
                  ),
                ),
              ],
            ),
          ] else ...[
            const Text(
              'Отримайте детальну статистику: години, рейтинг та прогрес по заходах.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/payment',
                  arguments: const PaymentArgs(planType: 'analytics'),
                ),
                icon: const Icon(Icons.bar_chart),
                label: const Text('Активувати за \$10'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnalyticsStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _AnalyticsStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Icon(icon, size: 80, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54, fontSize: 15),
        ),
      ],
    );
  }
}
