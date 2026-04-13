import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/test_config.dart';
import 'dashboard.dart';

/// Auth gate — requires kriket-admin superadmin login before the app opens.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _emailController = TextEditingController(text: TestConfig.superadminEmail);
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _authenticated = false;

  @override
  void initState() {
    super.initState();
    // Check if already logged in
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      _verifyRole();
    }
  }

  Future<void> _verifyRole() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();

      if (profile['role'] == 'superadmin') {
        setState(() => _authenticated = true);
      } else {
        setState(() => _error = 'Requires superadmin role. Your role: ${profile['role']}');
        await Supabase.instance.client.auth.signOut();
      }
    } catch (e) {
      setState(() => _error = 'Role verification failed: $e');
    }
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _error = 'Email and password required');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      await _verifyRole();

      if (!_authenticated) {
        setState(() => _error ??= 'Authentication failed — superadmin role required');
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Login error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_authenticated) {
      return const Dashboard();
    }

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Warning banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'INTERNAL TESTING ONLY\nContains admin credentials',
                          style: GoogleFonts.poppins(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Logo area
                Icon(Icons.science_rounded, size: 64, color: cs.primary),
                const SizedBox(height: 16),
                Text(
                  'BeautyCita Test Suite',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Superadmin authentication required',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 40),

                // Email field
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),

                // Password field
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  obscureText: true,
                  enabled: !_isLoading,
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 24),

                // Error
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: GoogleFonts.poppins(color: cs.error, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Login button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary),
                          )
                        : Text(
                            'Authenticate',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
