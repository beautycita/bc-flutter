import 'package:flutter/material.dart';
import 'package:beautycita_core/supabase.dart';

import '../../config/web_theme.dart';
import '../../config/breakpoints.dart';

/// Mi Cuenta — account management page.
/// Displays profile info with edit capabilities.
/// Sensitive operations (email change, password, delete) require re-auth.
class CuentaPage extends StatefulWidget {
  const CuentaPage({super.key});

  @override
  State<CuentaPage> createState() => _CuentaPageState();
}

class _CuentaPageState extends State<CuentaPage> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = BCSupabase.client.auth.currentUser;
    if (user == null) return;
    try {
      final data = await BCSupabase.client
          .from(BCTables.profiles)
          .select('username, full_name, phone, phone_verified, avatar_url, role, created_at')
          .eq('id', user.id)
          .single();
      if (mounted) {
        setState(() {
          _profile = {...data, 'email': user.email, 'id': user.id};
          _nameController.text = data['full_name'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await BCSupabase.client
          .from(BCTables.profiles)
          .update({'full_name': name})
          .eq('id', _profile!['id']);
      _profile!['full_name'] = name;
      if (mounted) setState(() => _saving = false);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = WebBreakpoints.isMobile(width);
    final pad = isMobile ? 16.0 : 32.0;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }

    final profile = _profile!;
    final avatarUrl = profile['avatar_url'] as String?;
    final username = profile['username'] as String? ?? '';
    final email = profile['email'] as String? ?? '';
    final phone = profile['phone'] as String? ?? '';
    final phoneVerified = profile['phone_verified'] == true;
    final role = profile['role'] as String? ?? 'customer';
    final createdAt = profile['created_at'] as String?;

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              const Text(
                'Mi Cuenta',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: kWebTextPrimary,
                  fontFamily: 'system-ui',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Administra tu perfil y configuracion de cuenta.',
                style: TextStyle(fontSize: 14, color: kWebTextSecondary, fontFamily: 'system-ui'),
              ),
              const SizedBox(height: 32),

              // ── Avatar + Username ──
              _card([
                Row(
                  children: [
                    avatarUrl != null
                        ? CircleAvatar(radius: 32, backgroundImage: NetworkImage(avatarUrl), backgroundColor: kWebCardBorder)
                        : Container(
                            width: 64, height: 64,
                            decoration: BoxDecoration(shape: BoxShape.circle, gradient: kWebBrandGradient),
                            child: Center(
                              child: Text(
                                username.isNotEmpty ? username[0].toUpperCase() : '?',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                          ),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('@$username', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kWebTextPrimary, fontFamily: 'system-ui')),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: kWebPrimary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            role == 'superadmin' ? 'Administrador' : role == 'stylist' ? 'Profesional' : 'Cliente',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kWebPrimary, fontFamily: 'system-ui'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ]),
              const SizedBox(height: 16),

              // ── Name ──
              _card([
                _fieldLabel('Nombre completo'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _textField(_nameController, 'Tu nombre'),
                    ),
                    const SizedBox(width: 12),
                    _actionButton('Guardar', _saving ? null : _saveName),
                  ],
                ),
              ]),
              const SizedBox(height: 16),

              // ── Email (read-only) ──
              _card([
                _fieldLabel('Correo electronico'),
                const SizedBox(height: 8),
                _readOnlyField(email, Icons.email_outlined),
              ]),
              const SizedBox(height: 16),

              // ── Phone ──
              _card([
                _fieldLabel('Telefono'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _readOnlyField(phone.isEmpty ? 'No registrado' : phone, Icons.phone_outlined)),
                    if (phoneVerified) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.verified, size: 20, color: Color(0xFF16A34A)),
                    ],
                  ],
                ),
              ]),
              const SizedBox(height: 16),

              // ── Account info ──
              _card([
                _fieldLabel('Informacion de cuenta'),
                const SizedBox(height: 12),
                _infoRow('ID de usuario', profile['id'].toString().substring(0, 8)),
                const SizedBox(height: 8),
                _infoRow('Miembro desde', createdAt != null ? DateTime.tryParse(createdAt)?.toLocal().toString().substring(0, 10) ?? '' : ''),
              ]),
              const SizedBox(height: 32),

              // ── Danger zone ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Zona de peligro', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFDC2626), fontFamily: 'system-ui')),
                    const SizedBox(height: 8),
                    const Text('Estas acciones son permanentes y no se pueden deshacer.', style: TextStyle(fontSize: 13, color: kWebTextSecondary, fontFamily: 'system-ui')),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        // TODO: implement with re-auth confirmation
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Contacta soporte@beautycita.com para eliminar tu cuenta.')),
                        );
                      },
                      icon: const Icon(Icons.delete_forever_outlined, size: 18, color: Color(0xFFDC2626)),
                      label: const Text('Eliminar cuenta', style: TextStyle(color: Color(0xFFDC2626))),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFECACA)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kWebSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kWebCardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _fieldLabel(String label) {
    return Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kWebTextSecondary, fontFamily: 'system-ui'));
  }

  Widget _textField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 14, color: kWebTextPrimary, fontFamily: 'system-ui'),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kWebTextHint),
        filled: true,
        fillColor: kWebBackground,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: kWebCardBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: kWebCardBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: kWebPrimary)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _readOnlyField(String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kWebBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kWebCardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: kWebTextHint),
          const SizedBox(width: 10),
          Text(value, style: const TextStyle(fontSize: 14, color: kWebTextSecondary, fontFamily: 'system-ui')),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: kWebTextSecondary, fontFamily: 'system-ui')),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kWebTextPrimary, fontFamily: 'system-ui')),
      ],
    );
  }

  Widget _actionButton(String label, VoidCallback? onTap) {
    return MouseRegion(
      cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: onTap != null ? kWebBrandGradient : null,
            color: onTap == null ? kWebCardBorder : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'system-ui')),
        ),
      ),
    );
  }
}
