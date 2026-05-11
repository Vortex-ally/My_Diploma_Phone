import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../providers/data_provider.dart';
import '../widgets/common/custom_text_field.dart';

class PaymentScreen extends StatefulWidget {
  final PaymentArgs args;
  const PaymentScreen({super.key, required this.args});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _card = TextEditingController(text: '4111 1111 1111 1111');
  final _name = TextEditingController(text: 'TEST USER');
  final _expiry = TextEditingController(text: '12/27');
  final _cvv = TextEditingController(text: '123');
  bool _processing = false;

  @override
  void dispose() {
    _card.dispose();
    _name.dispose();
    _expiry.dispose();
    _cvv.dispose();
    super.dispose();
  }

  String get _planLabel {
    switch (widget.args.planType) {
      case 'premium':
        return 'Преміум акаунт';
      case 'analytics':
        return 'Розширена аналітика';
      case 'priority':
        return 'Пріоритетне місце';
      default:
        return widget.args.planType;
    }
  }

  int get _price {
    switch (widget.args.planType) {
      case 'premium':
        return 20;
      case 'analytics':
        return 10;
      case 'priority':
        return 1;
      default:
        return 0;
    }
  }

  Future<void> _pay() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _processing = true);
    final ok = await context.read<DataProvider>().purchase(
          planType: widget.args.planType,
          projectId: widget.args.projectId,
          cardNumber: _card.text,
          cardholder: _name.text,
          expiry: _expiry.text,
          cvv: _cvv.text,
        );
    if (!mounted) return;
    setState(() => _processing = false);
    final err = context.read<DataProvider>().error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Оплату виконано' : (err ?? 'Платіж не пройшов'))),
    );
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Оплата')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.workspace_premium,
                        color: Colors.white, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      _planLabel,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.args.projectName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Захід: ${widget.args.projectName!}',
                          style:
                              TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      '\$$_price',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              CustomTextField(
                controller: _card,
                label: 'Номер картки',
                prefixIcon: Icons.credit_card,
                keyboardType: TextInputType.number,
                validator: (v) {
                  final digits = (v ?? '').replaceAll(' ', '');
                  if (digits.length < 12) return 'Невірний номер картки';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _name,
                label: 'Власник картки',
                prefixIcon: Icons.person,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Введіть ім\'я' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _expiry,
                      label: 'MM/YY',
                      prefixIcon: Icons.event,
                      keyboardType: TextInputType.datetime,
                      validator: (v) =>
                          (v == null || v.length < 4) ? 'Невірна дата' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      controller: _cvv,
                      label: 'CVV',
                      prefixIcon: Icons.password,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      validator: (v) =>
                          (v == null || v.length < 3) ? 'CVV' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _processing ? null : _pay,
                  icon: _processing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.lock),
                  label: Text('Сплатити \$$_price'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Тестова картка: 4111 1111 1111 1111 / 12/27 / 123',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.black45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
