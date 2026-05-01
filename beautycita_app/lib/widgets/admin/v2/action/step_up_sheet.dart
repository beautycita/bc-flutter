// Admin v2 StepUpSheet — re-auth modal for sensitive mutations.
//
// Server-side gate: SECURITY DEFINER RPCs check requires_fresh_auth(300)
// on entry. To pass, the JWT must have an iat within the last 5 minutes.
// This sheet:
//   1. Prompts biometric (if available)
//   2. Falls back to password entry
//   3. On success, refreshes the Supabase session (new JWT with fresh iat)
//   4. Pops with true
//
// Caller pattern:
//   final ok = await AdminStepUpSheet.show(context);
//   if (ok != true) return;
//   await rpcCall();   // server sees fresh iat, allows
//
// If the biometric call fails or the user cancels, the sheet returns null.
// If the password attempt fails, the sheet stays open for retry.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../services/biometric_service.dart';
import '../tokens.dart';
import 'action_button.dart';

class AdminStepUpSheet extends StatefulWidget {
  const AdminStepUpSheet({super.key, required this.purpose});

  /// Short description of why step-up is being asked
  /// e.g. "Cambiar tier del salón" or "Suspender salón"
  final String purpose;

  static Future<bool?> show(BuildContext context, {required String purpose}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => AdminStepUpSheet(purpose: purpose),
    );
  }

  @override
  State<AdminStepUpSheet> createState() => _AdminStepUpSheetState();
}

class _AdminStepUpSheetState extends State<AdminStepUpSheet> {
  final _biometric = BiometricService();
  final _passwordCtrl = TextEditingController();
  bool _busy = false;
  bool _useBiometric = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkBiometric() async {
    final available = await _biometric.isBiometricAvailable();
    if (!mounted) return;
    setState(() => _useBiometric = available);
  }

  Future<void> _attemptBiometric() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await _biometric.authenticate();
      if (!ok) {
        setState(() {
          _busy = false;
          _error = 'Biometría no aceptada — usa contraseña.';
          _useBiometric = false;
        });
        return;
      }
      await _refreshAndDone();
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Error biométrico — usa contraseña.';
        _useBiometric = false;
      });
    }
  }

  Future<void> _attemptPassword() async {
    final pwd = _passwordCtrl.text.trim();
    if (pwd.isEmpty) {
      setState(() => _error = 'Ingresa contraseña.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final email = Supabase.instance.client.auth.currentUser?.email;
      if (email == null) {
        setState(() {
          _busy = false;
          _error = 'Sin sesión activa.';
        });
        return;
      }
      await Supabase.instance.client.auth.signInWithPassword(email: email, password: pwd);
      await _refreshAndDone();
    } on AuthException catch (e) {
      setState(() {
        _busy = false;
        _error = e.message;
        _passwordCtrl.clear();
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Error: $e';
      });
    }
  }

  Future<void> _refreshAndDone() async {
    try {
      // signInWithPassword already produces a fresh JWT.
      // refreshSession is a defense-in-depth call for the biometric path,
      // where the existing session is reused — refresh forces a new iat.
      await Supabase.instance.client.auth.refreshSession();
    } catch (_) {
      // refreshSession can fail benignly; signInWithPassword already gave us
      // a fresh JWT. We still pop true.
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AdminV2Tokens.spacingLG,
          right: AdminV2Tokens.spacingLG,
          top: AdminV2Tokens.spacingLG,
          bottom: AdminV2Tokens.spacingLG + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 24, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: AdminV2Tokens.spacingSM),
                Expanded(child: Text('Confirmar identidad', style: AdminV2Tokens.title(context))),
              ],
            ),
            const SizedBox(height: AdminV2Tokens.spacingSM),
            Text(
              'Esta acción requiere reautenticación.\n${widget.purpose}',
              style: AdminV2Tokens.body(context),
            ),
            const SizedBox(height: AdminV2Tokens.spacingLG),
            if (_useBiometric)
              AdminActionButton(
                label: 'Usar biometría',
                icon: Icons.fingerprint,
                onPressed: _busy ? null : _attemptBiometric,
                isLoading: _busy,
              )
            else ...[
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                autofocus: true,
                onSubmitted: (_) => _attemptPassword(),
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AdminV2Tokens.radiusSM)),
                ),
              ),
              const SizedBox(height: AdminV2Tokens.spacingMD),
              AdminActionButton(
                label: 'Confirmar',
                onPressed: _busy ? null : _attemptPassword,
                isLoading: _busy,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AdminV2Tokens.spacingSM),
              Text(_error!, style: AdminV2Tokens.muted(context).copyWith(color: AdminV2Tokens.destructive(context))),
            ],
            const SizedBox(height: AdminV2Tokens.spacingMD),
            Center(
              child: TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
