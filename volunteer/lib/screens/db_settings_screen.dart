import 'package:flutter/material.dart';

import '../constants/db_config.dart';
import '../services/database_service.dart';
import '../widgets/common/custom_text_field.dart';

class DbSettingsScreen extends StatefulWidget {
  const DbSettingsScreen({super.key});

  @override
  State<DbSettingsScreen> createState() => _DbSettingsScreenState();
}

class _DbSettingsScreenState extends State<DbSettingsScreen> {
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _db;
  late final TextEditingController _user;
  late final TextEditingController _pass;
  bool _useSsl = false;
  bool _obscurePass = true;
  bool _saving = false;
  bool? _lastPingOk;
  String? _lastPingMessage;

  @override
  void initState() {
    super.initState();
    _host = TextEditingController(text: DbConfig.host);
    _port = TextEditingController(text: DbConfig.port.toString());
    _db = TextEditingController(text: DbConfig.database);
    _user = TextEditingController(text: DbConfig.username);
    _pass = TextEditingController(text: DbConfig.password);
    _useSsl = DbConfig.useSsl;
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _db.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _save({bool ping = false}) async {
    final port = int.tryParse(_port.text.trim());
    if (port == null || port <= 0) {
      _toast('Невірний порт');
      return;
    }
    if (_host.text.trim().isEmpty || _db.text.trim().isEmpty) {
      _toast('Заповніть host і database');
      return;
    }
    setState(() => _saving = true);
    try {
      await DbConfig.save(
        host: _host.text.trim(),
        port: port,
        database: _db.text.trim(),
        username: _user.text.trim(),
        password: _pass.text,
        useSsl: _useSsl,
      );
      // Reset live connection so the next call uses the new settings.
      await DatabaseService().close();
      if (ping) {
        final ok = await DatabaseService().ping();
        if (!mounted) return;
        setState(() {
          _lastPingOk = ok;
          _lastPingMessage = ok
              ? 'Підключено до БД ✓'
              : "Не вдалося з'єднатися з БД";
        });
      } else {
        if (!mounted) return;
        _toast('Збережено');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastPingOk = false;
        _lastPingMessage = e.toString();
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Підключення до БД')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Мобільний застосунок підключається напряму до тієї самої '
              'PostgreSQL бази, що й Django backend (web). Налаштування мають '
              'збігатися з `DATABASES` у settings.py.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _host,
              label: 'Host',
              prefixIcon: Icons.dns,
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _port,
              label: 'Port',
              prefixIcon: Icons.numbers,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _db,
              label: 'Database',
              prefixIcon: Icons.storage,
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _user,
              label: 'Username',
              prefixIcon: Icons.person_outline,
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _pass,
              label: 'Password',
              prefixIcon: Icons.key,
              obscureText: _obscurePass,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePass ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () => setState(() => _obscurePass = !_obscurePass),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _useSsl,
              onChanged: (v) => setState(() => _useSsl = v),
              title: const Text('SSL'),
              subtitle: const Text('Увімкніть для віддалених/хмарних БД'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : () => _save(ping: true),
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.network_check),
              label: const Text('Зберегти і перевірити'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _saving ? null : () => _save(ping: false),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Лише зберегти'),
            ),
            if (_lastPingMessage != null) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (_lastPingOk == true ? Colors.green : Colors.red)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_lastPingOk == true ? Colors.green : Colors.red)
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _lastPingOk == true
                          ? Icons.check_circle
                          : Icons.error_outline,
                      color: _lastPingOk == true ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_lastPingMessage!)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Що треба для підключення з телефону:\n'
              '1) У postgresql.conf:  listen_addresses = \'*\'\n'
              '2) У pg_hba.conf додайте рядок:\n'
              '   host  volunteer_db  postgres  0.0.0.0/0  md5\n'
              '3) Перезапустіть Postgres та переконайтесь, що порт 5432 '
              'відкритий у файрволі.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.black54,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
