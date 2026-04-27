import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../config/breakpoints.dart';
import '../../config/router.dart';
import '../../config/web_theme.dart';
import '../../providers/auth_provider.dart';

/// Mi Cuenta — single comprehensive account page.
/// Profile, privacy, ARCO data rights, legal, and danger zone.
class CuentaPage extends ConsumerStatefulWidget {
  const CuentaPage({super.key});

  @override
  ConsumerState<CuentaPage> createState() => _CuentaPageState();
}

class _CuentaPageState extends ConsumerState<CuentaPage> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _savingName = false;
  bool _uploadingAvatar = false;
  bool _sendingPasswordReset = false;
  bool _analyticsOn = true;
  bool _marketingOn = true;
  String? _error;

  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final user = BCSupabase.client.auth.currentUser;
    if (user == null) return;
    try {
      final data = await BCSupabase.client
          .from(BCTables.profiles)
          .select(
            'username, full_name, phone, phone_verified, avatar_url, role, '
            'created_at, opted_out_analytics, opted_out_marketing',
          )
          .eq('id', user.id)
          .single();
      if (!mounted) return;
      setState(() {
        _profile = {...data, 'email': user.email, 'id': user.id};
        _nameController.text = (data['full_name'] as String?) ?? '';
        _analyticsOn = data['opted_out_analytics'] != true;
        _marketingOn = data['opted_out_marketing'] != true;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _profile == null) return;
    setState(() => _savingName = true);
    try {
      await BCSupabase.client
          .from(BCTables.profiles)
          .update({'full_name': name})
          .eq('id', _profile!['id']);
      _profile!['full_name'] = name;
      _snack('Nombre actualizado');
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _uploadAvatar() async {
    final user = BCSupabase.client.auth.currentUser;
    if (user == null) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty || result.files.first.bytes == null) return;
    final file = result.files.first;
    if (file.bytes!.length > 5 * 1024 * 1024) {
      _snack('La imagen debe ser menor a 5 MB');
      return;
    }
    setState(() => _uploadingAvatar = true);
    try {
      final ext = (file.extension ?? 'jpg').toLowerCase();
      final path = '${user.id}/avatar.$ext';
      await BCSupabase.client.storage
          .from('avatars')
          .uploadBinary(
            path,
            file.bytes!,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );
      // Cache-bust so the new avatar shows immediately
      final publicUrl =
          '${BCSupabase.client.storage.from('avatars').getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
      await BCSupabase.client
          .from(BCTables.profiles)
          .update({'avatar_url': publicUrl})
          .eq('id', user.id);
      if (!mounted) return;
      setState(() => _profile!['avatar_url'] = publicUrl);
      _snack('Foto actualizada');
    } catch (e) {
      _snack('Error subiendo foto: $e');
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _profile?['email'] as String?;
    if (email == null) return;
    setState(() => _sendingPasswordReset = true);
    try {
      await BCSupabase.client.auth.resetPasswordForEmail(email);
      _snack('Te enviamos un correo a $email para restablecer tu contraseña.');
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _sendingPasswordReset = false);
    }
  }

  Future<void> _toggleAnalytics(bool value) async {
    final previous = _analyticsOn;
    setState(() => _analyticsOn = value);
    try {
      await BCSupabase.client
          .from(BCTables.profiles)
          .update({
            'opted_out_analytics': !value,
            if (!value) 'opted_out_analytics_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', _profile!['id']);
    } catch (_) {
      if (mounted) {
        setState(() => _analyticsOn = previous);
        _snack('Error al guardar');
      }
    }
  }

  Future<void> _toggleMarketing(bool value) async {
    final previous = _marketingOn;
    setState(() => _marketingOn = value);
    try {
      await BCSupabase.client
          .from(BCTables.profiles)
          .update({'opted_out_marketing': !value})
          .eq('id', _profile!['id']);
    } catch (_) {
      if (mounted) {
        setState(() => _marketingOn = previous);
        _snack('Error al guardar');
      }
    }
  }

  Future<void> _requestDataExport() async {
    final confirm = await _confirmDialog(
      title: 'Solicitar mis datos',
      body: 'Generaremos un archivo JSON con todos tus datos personales y te lo enviaremos por correo. '
          'El enlace de descarga es válido por 24 horas. Puedes solicitar una exportación cada 24 horas.',
      confirmLabel: 'Solicitar',
    );
    if (confirm != true) return;
    try {
      final response = await BCSupabase.client.functions.invoke(
        'arco-request',
        body: {'request_type': 'access'},
      );
      if (response.status == 201 || response.status == 200) {
        _snack('Solicitud recibida. Revisa tu correo en unos minutos.');
      } else {
        final err = response.data is Map ? response.data['error'] : 'Error desconocido';
        _snack('Error: $err');
      }
    } catch (e) {
      _snack('Error: $e');
    }
  }

  Future<void> _requestOpposition() async {
    final reason = await _textInputDialog(
      title: 'Oponerte al perfilado',
      body: 'Detén el análisis de comportamiento sobre tu cuenta. '
          'Tus traits se eliminarán dentro de 30 días. Cuéntanos brevemente por qué te opones (opcional).',
      hint: 'Razón (opcional)',
    );
    if (reason == null) return;
    try {
      final response = await BCSupabase.client.functions.invoke(
        'arco-request',
        body: {
          'request_type': 'opposition',
          'details': {
            'processing_type': 'behavioral_analytics',
            if (reason.isNotEmpty) 'reason': reason,
          },
        },
      );
      if (response.status == 201 || response.status == 200) {
        if (mounted) setState(() => _analyticsOn = false);
        _snack('Oposición registrada. Análisis desactivado.');
      } else {
        final err = response.data is Map ? response.data['error'] : 'Error desconocido';
        _snack('Error: $err');
      }
    } catch (e) {
      _snack('Error: $e');
    }
  }

  Future<void> _requestAccountDeletion() async {
    final confirm = await _confirmDialog(
      title: 'Eliminar mi cuenta',
      body: 'Esta solicitud iniciará el proceso de eliminación de tu cuenta conforme al artículo 25 de la LFPDPPP. '
          'Un administrador revisará tu solicitud y verificará que no tengas citas pendientes, saldo, '
          'negocios activos o disputas abiertas antes de proceder. Plazo máximo: 20 días hábiles.\n\n'
          'Esta acción es PERMANENTE y no se puede deshacer.',
      confirmLabel: 'Solicitar eliminación',
      destructive: true,
    );
    if (confirm != true) return;
    try {
      final response = await BCSupabase.client.functions.invoke(
        'arco-request',
        body: {'request_type': 'cancellation'},
      );
      if (response.status == 201 || response.status == 200) {
        _snack('Solicitud registrada. Te contactaremos dentro de 20 días hábiles.');
      } else {
        final err = response.data is Map ? response.data['error'] : 'Error desconocido';
        _snack('Error: $err');
      }
    } catch (e) {
      _snack('Error: $e');
    }
  }

  Future<void> _logout() async {
    final confirm = await _confirmDialog(
      title: 'Cerrar sesión',
      body: '¿Cerrar sesión en este navegador?',
      confirmLabel: 'Cerrar sesión',
    );
    if (confirm != true) return;
    await ref.read(authProvider.notifier).signOut();
    if (mounted) context.go(WebRoutes.auth);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String body,
    required String confirmLabel,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kWebSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(title, style: const TextStyle(fontFamily: 'system-ui', fontWeight: FontWeight.w700)),
        content: Text(body, style: const TextStyle(fontFamily: 'system-ui', fontSize: 14, color: kWebTextSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: destructive ? const Color(0xFFDC2626) : kWebPrimary,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Future<String?> _textInputDialog({
    required String title,
    required String body,
    required String hint,
  }) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kWebSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(title, style: const TextStyle(fontFamily: 'system-ui', fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body, style: const TextStyle(fontFamily: 'system-ui', fontSize: 14, color: kWebTextSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: hint,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = WebBreakpoints.isMobile(width);
    final pad = isMobile ? 16.0 : 32.0;

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));

    final profile = _profile!;
    final avatarUrl = profile['avatar_url'] as String?;
    final username = (profile['username'] as String?) ?? '';
    final email = (profile['email'] as String?) ?? '';
    final phone = (profile['phone'] as String?) ?? '';
    final phoneVerified = profile['phone_verified'] == true;
    final role = (profile['role'] as String?) ?? 'customer';
    final createdAt = profile['created_at'] as String?;
    final memberSince = createdAt != null
        ? DateTime.tryParse(createdAt)?.toLocal().toString().substring(0, 10) ?? ''
        : '';

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Header ──
              const Text(
                'Mi Cuenta',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: kWebTextPrimary, fontFamily: 'system-ui'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tu perfil, privacidad y derechos sobre tus datos.',
                style: TextStyle(fontSize: 14, color: kWebTextSecondary, fontFamily: 'system-ui'),
              ),
              const SizedBox(height: 32),

              // ── 2. Avatar + identity ──
              _card([
                Row(
                  children: [
                    _avatarWidget(avatarUrl, username),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('@$username',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kWebTextPrimary, fontFamily: 'system-ui')),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _roleBadge(role),
                              if (memberSince.isNotEmpty)
                                Text('Miembro desde $memberSince',
                                    style: const TextStyle(fontSize: 12, color: kWebTextHint, fontFamily: 'system-ui')),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _ghostButton(
                      _uploadingAvatar ? 'Subiendo…' : 'Cambiar foto',
                      _uploadingAvatar ? null : _uploadAvatar,
                      icon: Icons.photo_camera_outlined,
                    ),
                  ],
                ),
              ]),
              const SizedBox(height: 16),

              // ── 3. Personal info ──
              _card([
                _fieldLabel('Nombre completo'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _textField(_nameController, 'Tu nombre')),
                    const SizedBox(width: 12),
                    _primaryButton(_savingName ? 'Guardando…' : 'Guardar', _savingName ? null : _saveName),
                  ],
                ),
                const SizedBox(height: 20),
                _fieldLabel('Correo electrónico'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _readOnlyField(email, Icons.email_outlined)),
                    const SizedBox(width: 12),
                    _ghostButton(
                      _sendingPasswordReset ? 'Enviando…' : 'Restablecer contraseña',
                      _sendingPasswordReset || email.isEmpty ? null : _sendPasswordReset,
                      icon: Icons.lock_reset_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _fieldLabel('Teléfono'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _readOnlyField(phone.isEmpty ? 'No registrado' : phone, Icons.phone_outlined)),
                    if (phoneVerified) ...[
                      const SizedBox(width: 8),
                      const Tooltip(
                        message: 'Verificado',
                        child: Icon(Icons.verified, size: 20, color: Color(0xFF16A34A)),
                      ),
                    ],
                  ],
                ),
              ]),
              const SizedBox(height: 32),

              // ── 4. Privacy ──
              _sectionHeader('Privacidad'),
              const SizedBox(height: 12),
              _toggleCard(
                icon: Icons.analytics_outlined,
                title: 'Análisis de actividad',
                subtitle:
                    'Permite analizar tu actividad para mejorar recomendaciones. Si lo desactivas, tus datos de análisis se eliminan en 30 días.',
                value: _analyticsOn,
                onChanged: _toggleAnalytics,
              ),
              const SizedBox(height: 12),
              _toggleCard(
                icon: Icons.campaign_outlined,
                title: 'Comunicaciones de marketing',
                subtitle: 'Recibe promociones, ofertas y novedades por correo o WhatsApp.',
                value: _marketingOn,
                onChanged: _toggleMarketing,
              ),
              const SizedBox(height: 32),

              // ── 5. ARCO data rights ──
              _sectionHeader('Tus derechos sobre tus datos (ARCO)'),
              const SizedBox(height: 8),
              const Text(
                'Conforme a la LFPDPPP, tienes derecho a Acceder, Rectificar, Cancelar y Oponerte al uso de tus datos personales. Plazo de respuesta: 20 días hábiles.',
                style: TextStyle(fontSize: 13, color: kWebTextSecondary, fontFamily: 'system-ui'),
              ),
              const SizedBox(height: 12),
              _card([
                _arcoRow(
                  icon: Icons.download_outlined,
                  title: 'Solicitar mis datos (Acceso)',
                  subtitle: 'Recibe un archivo con todos tus datos personales por correo.',
                  buttonLabel: 'Solicitar',
                  onTap: _requestDataExport,
                ),
                const Divider(color: kWebCardBorder, height: 28),
                _arcoRow(
                  icon: Icons.block_outlined,
                  title: 'Oponerme al perfilado (Oposición)',
                  subtitle: 'Detén el análisis de comportamiento. Equivalente a desactivar el switch superior.',
                  buttonLabel: 'Solicitar',
                  onTap: _requestOpposition,
                ),
              ]),
              const SizedBox(height: 32),

              // ── 6. Legal ──
              _sectionHeader('Legal'),
              const SizedBox(height: 12),
              _card([
                _legalLink('Aviso de privacidad', WebRoutes.privacidad),
                const Divider(color: kWebCardBorder, height: 24),
                _legalLink('Términos y condiciones', WebRoutes.terminos),
              ]),
              const SizedBox(height: 32),

              // ── 7. Danger zone ──
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
                    const Text('Zona de peligro',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFDC2626), fontFamily: 'system-ui')),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _dangerButton(
                          icon: Icons.logout_outlined,
                          label: 'Cerrar sesión',
                          onTap: _logout,
                        ),
                        _dangerButton(
                          icon: Icons.delete_forever_outlined,
                          label: 'Solicitar eliminación de cuenta',
                          onTap: _requestAccountDeletion,
                        ),
                      ],
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

  // ── widgets ────────────────────────────────────────────────────────────

  Widget _card(List<Widget> children) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kWebSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kWebCardBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _sectionHeader(String title) => Text(title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kWebTextPrimary, fontFamily: 'system-ui'));

  Widget _fieldLabel(String label) => Text(label,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kWebTextSecondary, fontFamily: 'system-ui'));

  Widget _avatarWidget(String? url, String username) {
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(radius: 32, backgroundImage: NetworkImage(url), backgroundColor: kWebCardBorder);
    }
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: kWebBrandGradient),
      child: Center(
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : '?',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
    );
  }

  Widget _roleBadge(String role) {
    final label = role == 'superadmin'
        ? 'Administrador'
        : role == 'admin'
            ? 'Administrador'
            : role == 'stylist'
                ? 'Profesional'
                : role == 'salon_owner'
                    ? 'Negocio'
                    : 'Cliente';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: kWebPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kWebPrimary, fontFamily: 'system-ui'),
      ),
    );
  }

  Widget _textField(TextEditingController controller, String hint) => TextField(
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

  Widget _readOnlyField(String value, IconData icon) => Container(
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
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 14, color: kWebTextSecondary, fontFamily: 'system-ui'),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );

  Widget _toggleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kWebSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kWebCardBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: kWebPrimary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kWebTextPrimary, fontFamily: 'system-ui')),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: kWebTextSecondary, fontFamily: 'system-ui')),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch.adaptive(value: value, onChanged: onChanged, activeThumbColor: kWebPrimary),
          ],
        ),
      );

  Widget _arcoRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onTap,
  }) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: kWebPrimary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kWebTextPrimary, fontFamily: 'system-ui')),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 13, color: kWebTextSecondary, fontFamily: 'system-ui')),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _ghostButton(buttonLabel, onTap),
        ],
      );

  Widget _legalLink(String label, String route) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => context.go(route),
          child: Row(
            children: [
              const Icon(Icons.description_outlined, size: 18, color: kWebTextSecondary),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: kWebTextPrimary, fontFamily: 'system-ui'))),
              const Icon(Icons.chevron_right, size: 18, color: kWebTextHint),
            ],
          ),
        ),
      );

  Widget _primaryButton(String label, VoidCallback? onTap) => MouseRegion(
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
            child: Text(label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'system-ui')),
          ),
        ),
      );

  Widget _ghostButton(String label, VoidCallback? onTap, {IconData? icon}) => MouseRegion(
        cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: kWebSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: onTap != null ? kWebCardBorder : kWebCardBorder.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: onTap != null ? kWebTextPrimary : kWebTextHint),
                  const SizedBox(width: 6),
                ],
                Text(label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: onTap != null ? kWebTextPrimary : kWebTextHint,
                      fontFamily: 'system-ui',
                    )),
              ],
            ),
          ),
        ),
      );

  Widget _dangerButton({required IconData icon, required String label, required VoidCallback onTap}) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: const Color(0xFFDC2626)),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFDC2626),
                      fontFamily: 'system-ui',
                    )),
              ],
            ),
          ),
        ),
      );
}
