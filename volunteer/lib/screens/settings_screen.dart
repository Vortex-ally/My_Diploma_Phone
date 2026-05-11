import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/common/custom_text_field.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _group;

  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _firstName = TextEditingController(text: user?.firstName ?? '');
    _lastName = TextEditingController(text: user?.lastName ?? '');
    _group = TextEditingController(text: user?.groupName ?? '');
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _group.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;
    setState(() => _savingProfile = true);
    final ok = await context.read<AuthProvider>().updateProfile(
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          groupName: _group.text.trim(),
        );
    if (!mounted) return;
    setState(() => _savingProfile = false);
    final err = context.read<AuthProvider>().error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Профіль оновлено' : (err ?? 'Не вдалося оновити профіль'),
        ),
      ),
    );
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    if (_newPassword.text != _confirmPassword.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нові паролі не співпадають')),
      );
      return;
    }
    setState(() => _savingPassword = true);
    final ok = await context.read<AuthProvider>().changePassword(
          currentPassword: _currentPassword.text,
          newPassword: _newPassword.text,
        );
    if (!mounted) return;
    setState(() => _savingPassword = false);
    final err = context.read<AuthProvider>().error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Пароль змінено' : (err ?? 'Не вдалося змінити пароль'),
        ),
      ),
    );
    if (ok) {
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Налаштування')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
              icon: Icons.person_outline,
              title: 'Особисті дані',
            ),
            Form(
              key: _profileFormKey,
              child: Column(
                children: [
                  CustomTextField(
                    controller: _firstName,
                    label: "Ім'я",
                    prefixIcon: Icons.badge_outlined,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? "Введіть ім'я" : null,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _lastName,
                    label: 'Прізвище',
                    prefixIcon: Icons.badge,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _group,
                    label: 'Група (наприклад, IT-21)',
                    prefixIcon: Icons.group,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _savingProfile ? null : _saveProfile,
                      icon: _savingProfile
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: const Text('Зберегти'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _SectionHeader(
              icon: Icons.lock_outline,
              title: 'Зміна паролю',
            ),
            Form(
              key: _passwordFormKey,
              child: Column(
                children: [
                  CustomTextField(
                    controller: _currentPassword,
                    label: 'Поточний пароль',
                    prefixIcon: Icons.lock,
                    obscureText: _obscure,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Введіть поточний пароль' : null,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _newPassword,
                    label: 'Новий пароль',
                    prefixIcon: Icons.lock_open,
                    obscureText: _obscure,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Введіть новий пароль';
                      if (v.length < 6) return 'Мінімум 6 символів';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _confirmPassword,
                    label: 'Підтвердіть пароль',
                    prefixIcon: Icons.lock_open,
                    obscureText: _obscure,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Підтвердіть пароль' : null,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _savingPassword ? null : _changePassword,
                      icon: _savingPassword
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.password),
                      label: const Text('Змінити пароль'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const _SectionHeader(
              icon: Icons.storage_outlined,
              title: 'Підключення',
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.storage_outlined),
              title: const Text('Підключення до БД'),
              subtitle: const Text(
                'Прямий PostgreSQL до спільної бази з web',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/server'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
