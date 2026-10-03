import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
 
import '../core/api_client.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import 'otp_screen.dart';
 
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
 
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}
 
class _LoginScreenState extends State<LoginScreen> {
  final _controller = TextEditingController();
  bool _useEmail = false;
  bool _loading = false;
 
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
 
  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
 
  String? _validate(String value) {
    if (_useEmail) {
      return kEmailRegex.hasMatch(value) ? null : 'Enter a valid email address.';
    }
    return kPhoneRegex.hasMatch(cleanPhone(value))
        ? null
        : 'Enter 10 digits (e.g. 9876543210) or +91 followed by 10 digits.';
  }
 
  Future<void> _sendOtp() async {
    final raw = _controller.text.trim();
    final error = _validate(raw);
    if (error != null) {
      _toast(error);
      return;
    }
    final value = _useEmail ? raw.toLowerCase() : cleanPhone(raw);
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().sendOtp(
            phone: _useEmail ? '' : value,
            email: _useEmail ? value : '',
          );
      if (!mounted) return;
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const OtpScreen()));
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log in or sign up')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: false, label: Text('Mobile'), icon: Icon(Icons.phone)),
                ButtonSegment(
                    value: true, label: Text('Email'), icon: Icon(Icons.email)),
              ],
              selected: {_useEmail},
              onSelectionChanged: (s) => setState(() {
                _useEmail = s.first;
                _controller.clear();
              }),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              keyboardType:
                  _useEmail ? TextInputType.emailAddress : TextInputType.phone,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: _useEmail ? 'Email address' : 'Mobile number',
                hintText: _useEmail ? 'you@example.com' : '9876543210',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _sendOtp,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Send OTP'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}