import 'package:flutter/material.dart';
import 'package:beautycita_core/supabase.dart';

import '../../config/web_theme.dart';
import '../../config/breakpoints.dart';

/// Configuracion — user preferences and privacy settings.
class ConfiguracionPage extends StatefulWidget {
  const ConfiguracionPage({super.key});

  @override
  State<ConfiguracionPage> createState() => _ConfiguracionPageState();
}

class _ConfiguracionPageState extends State<ConfiguracionPage> {
  bool _loading = true;
  bool _analyticsOn = true;
  bool _marketingOn = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final user = BCSupabase.client.auth.currentUser;
    if (user == null) return;
    try {
      final data = await BCSupabase.client
          .from(BCTables.profiles)
          .select('opted_out_analytics, opted_out_marketing')
          .eq('id', user.id)
          .single();
      if (mounted) {
        setState(() {
          _analyticsOn = data['opted_out_analytics'] != true;
          _marketingOn = data['opted_out_marketing'] != true;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _toggleAnalytics(bool value) async {
    final previous = _analyticsOn;
    setState(() => _analyticsOn = value);
    try {
      final user = BCSupabase.client.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');
      await BCSupabase.client
          .from(BCTables.profiles)
          .update({
            'opted_out_analytics': !value,
            if (!value) 'opted_out_analytics_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', user.id);
    } catch (e) {
      if (mounted) {
        setState(() => _analyticsOn = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar. Intenta de nuevo.')),
        );
      }
    }
  }

  Future<void> _toggleMarketing(bool value) async {
    final previous = _marketingOn;
    setState(() => _marketingOn = value);
    try {
      final user = BCSupabase.client.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');
      await BCSupabase.client
          .from(BCTables.profiles)
          .update({'opted_out_marketing': !value})
          .eq('id', user.id);
    } catch (e) {
      if (mounted) {
        setState(() => _marketingOn = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar. Intenta de nuevo.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = WebBreakpoints.isMobile(width);
    final pad = isMobile ? 16.0 : 32.0;

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Configuracion',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: kWebTextPrimary, fontFamily: 'system-ui'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Controla tu privacidad y preferencias.',
                style: TextStyle(fontSize: 14, color: kWebTextSecondary, fontFamily: 'system-ui'),
              ),
              const SizedBox(height: 32),

              // ── Privacy ──
              _sectionHeader('Privacidad'),
              const SizedBox(height: 12),
              _toggleCard(
                icon: Icons.analytics_outlined,
                title: 'Analisis de actividad',
                subtitle: 'Permite analizar tu actividad para mejorar recomendaciones. Puedes desactivarlo en cualquier momento y tus datos se eliminan en 30 dias.',
                value: _analyticsOn,
                onChanged: _toggleAnalytics,
              ),
              const SizedBox(height: 12),
              _toggleCard(
                icon: Icons.campaign_outlined,
                title: 'Comunicaciones de marketing',
                subtitle: 'Recibe promociones, ofertas y novedades por email o WhatsApp.',
                value: _marketingOn,
                onChanged: _toggleMarketing,
              ),
              const SizedBox(height: 32),

              // ── Data rights ──
              _sectionHeader('Tus derechos (ARCO)'),
              const SizedBox(height: 12),
              _card([
                const Text(
                  'Tienes derecho a Acceder, Rectificar, Cancelar y Oponerte al uso de tus datos personales.',
                  style: TextStyle(fontSize: 14, color: kWebTextSecondary, fontFamily: 'system-ui'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Para ejercer tus derechos ARCO, contacta: soporte@beautycita.com',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kWebTextPrimary, fontFamily: 'system-ui'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tiempo de respuesta: 20 dias habiles conforme a la LFPDPPP.',
                  style: TextStyle(fontSize: 12, color: kWebTextHint, fontFamily: 'system-ui'),
                ),
              ]),
              const SizedBox(height: 32),

              // ── Legal links ──
              _sectionHeader('Legal'),
              const SizedBox(height: 12),
              _card([
                _legalLink('Aviso de privacidad', '/privacidad'),
                const Divider(color: kWebCardBorder, height: 24),
                _legalLink('Terminos y condiciones', '/terminos'),
              ]),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kWebTextPrimary, fontFamily: 'system-ui'));
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

  Widget _toggleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
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
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kWebTextPrimary, fontFamily: 'system-ui')),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 13, color: kWebTextSecondary, fontFamily: 'system-ui')),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: kWebPrimary,
          ),
        ],
      ),
    );
  }

  Widget _legalLink(String label, String route) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pushNamed(route),
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
  }
}
