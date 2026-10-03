import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
 
import '../core/api_client.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
 
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});
 
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}
 
class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _other = TextEditingController();
  final _pin = TextEditingController();
  String _language = 'English';
  String? _role;
  bool _loading = false;
 
  @override
  void dispose() {
    _name.dispose();
    _other.dispose();
    _pin.dispose();
    super.dispose();
  }
 
  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
 
  Future<void> _submit(bool verifiedByPhone) async {
    if (!_formKey.currentState!.validate()) return;
    if (_role == null) {
      _toast('Please choose whether you are a Seller or a Buyer.');
      return;
    }
    final other = _other.text.trim();
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().register(
            fullName: _name.text.trim(),
            phone: verifiedByPhone ? '' : cleanPhone(other),
            email: verifiedByPhone ? other.toLowerCase() : '',
            pinCode: _pin.text.trim(),
            language: _language,
            role: _role!,
          );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
 
  Widget _roleCard(String role, IconData icon, String subtitle) {
    final selected = _role == role;
    final color = Theme.of(context).colorScheme.primary;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _role = role),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? color : Colors.grey.shade400,
                width: selected ? 2.5 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, size: 34, color: selected ? color : Colors.grey),
              const SizedBox(height: 6),
              Text(role, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    final verifiedByPhone =
        context.read<AuthProvider>().pendingPhone.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Set up your profile')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(), labelText: 'Full name'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter your name.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _other,
                keyboardType: verifiedByPhone
                    ? TextInputType.emailAddress
                    : TextInputType.phone,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: verifiedByPhone
                      ? 'Email (optional)'
                      : 'Mobile number (optional)',
                ),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return null;
                  if (verifiedByPhone) {
                    return kEmailRegex.hasMatch(value)
                        ? null
                        : 'Enter a valid email address.';
                  }
                  return kPhoneRegex.hasMatch(cleanPhone(value))
                      ? null
                      : 'Enter 10 digits, or +91 followed by 10 digits.';
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pin,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(), labelText: 'PIN code'),
                validator: (v) => RegExp(r'^\d{6}$').hasMatch((v ?? '').trim())
                    ? null
                    : 'Enter your 6-digit PIN code.',
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _language,
                isExpanded: true,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(), labelText: 'Preferred language'),
                items: kLanguages
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) => setState(() => _language = v ?? 'English'),
              ),
              const SizedBox(height: 24),
              const Text('I am a...',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _roleCard('Seller', Icons.storefront, 'I make and sell crafts'),
                  const SizedBox(width: 12),
                  _roleCard('Buyer', Icons.shopping_bag, 'I want to buy crafts'),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : () => _submit(verifiedByPhone),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Create account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}