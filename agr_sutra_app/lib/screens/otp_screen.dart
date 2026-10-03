import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
 
import '../core/api_client.dart';
import '../providers/auth_provider.dart';
import 'profile_setup_screen.dart';
 
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});
 
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}
 
class _OtpScreenState extends State<OtpScreen> {
  final _controller = TextEditingController();
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
 
  Future<void> _verify() async {
    final code = _controller.text.trim();
    if (code.length != 6) {
      _toast('Enter the 6-digit code.');
      return;
    }
    setState(() => _loading = true);
    try {
      final isNew = await context.read<AuthProvider>().verifyOtp(code);
      if (!mounted) return;
      if (isNew) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
        );
      } else {
        // Returning user: they are now logged in. Go back to the root,
        // which switches to the home screen by itself.
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
 
  Future<void> _resend() async {
    final auth = context.read<AuthProvider>();
    try {
      await auth.sendOtp(phone: auth.pendingPhone, email: auth.pendingEmail);
      _toast('A new code was generated.');
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }
 
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final contact =
        auth.pendingPhone.isNotEmpty ? auth.pendingPhone : auth.pendingEmail;
    return Scaffold(
      appBar: AppBar(title: const Text('Verify code')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Enter the 6-digit code for $contact'),
            const SizedBox(height: 16),
            if (auth.demoOtp != null)
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                      'Demo mode: no SMS or email is sent.\nYour code is ${auth.demoOtp}'),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: '6-digit code',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _loading ? null : _verify,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Verify'),
              ),
            ),
            TextButton(onPressed: _resend, child: const Text('Resend code')),
          ],
        ),
      ),
    );
  }
}