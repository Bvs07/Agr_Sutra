import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
 
import '../core/api_client.dart';
import '../core/constants.dart';
import '../core/location_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/stars.dart';
 
/// Profile settings for both Sellers and Buyers.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
 
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}
 
class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _pin;
  late String _language;
  bool _saving = false;
  bool _locating = false;
 
  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user!;
    _name = TextEditingController(text: user.fullName);
    _phone = TextEditingController(text: user.phone);
    _email = TextEditingController(text: user.email);
    _pin = TextEditingController(text: user.pinCode);
    _language = kLanguages.contains(user.language) ? user.language : 'English';
  }
 
  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _pin.dispose();
    super.dispose();
  }
 
  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
 
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final phone = _phone.text.trim();
      await context.read<AuthProvider>().updateProfile(
            fullName: _name.text.trim(),
            phone: phone.isEmpty ? null : cleanPhone(phone),
            email: _email.text.trim().isEmpty
                ? null
                : _email.text.trim().toLowerCase(),
            pinCode: _pin.text.trim(),
            language: _language,
          );
      _toast('Profile saved.');
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
 
  Future<void> _updateLocation() async {
    setState(() => _locating = true);
    try {
      final position = await getCurrentPosition();
      if (!mounted) return;
      await context.read<AuthProvider>().updateProfile(
            latitude: position.latitude,
            longitude: position.longitude,
          );
      _toast('Location updated.');
    } on LocationException catch (e) {
      _toast(e.message);
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('Could not get your location: $e');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }
 
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;
    return Scaffold(
      appBar: AppBar(title: const Text('My profile')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Chip(
                    avatar: Icon(user.isSeller ? Icons.storefront : Icons.shopping_bag, size: 18),
                    label: Text(user.role),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.isSeller ? 'Your store rating' : 'Your buyer rating',
                            style: const TextStyle(fontSize: 12)),
                        StarDisplay(
                            rating: user.ratingAverage, count: user.ratingCount),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
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
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(), labelText: 'Mobile number'),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return null;
                  return kPhoneRegex.hasMatch(cleanPhone(value))
                      ? null
                      : 'Enter 10 digits, or +91 followed by 10 digits.';
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(), labelText: 'Email'),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return null;
                  return kEmailRegex.hasMatch(value)
                      ? null
                      : 'Enter a valid email address.';
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
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save changes'),
                ),
              ),
              const Divider(height: 40),
              Text('Location', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(user.hasLocation
                  ? 'Saved: ${user.latitude!.toStringAsFixed(4)}, ${user.longitude!.toStringAsFixed(4)}'
                  : 'No location saved yet.'),
              if (user.isSeller)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Buyers can open your location from the product page.',
                      style: TextStyle(fontSize: 12)),
                ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _locating ? null : _updateLocation,
                icon: _locating
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location),
                label: Text(user.hasLocation ? 'Refresh my location' : 'Share my location'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}