// =============================================================================
// Public QR registration page — /registro/:slug
// =============================================================================
// Served at beautycita.com/registro/:internal_qr_slug. The salon's client
// scans the internal QR on their own phone, this page loads in the browser,
// they fill the form + three consent checkboxes, OTP if required, submit.
//
// Design: /home/bc/futureBeauty/docs/plans/2026-04-23-salon-qr-90day.md §6.1
// =============================================================================

import 'dart:math';
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QrRegistroPage extends StatefulWidget {
  final String slug;
  const QrRegistroPage({super.key, required this.slug});

  @override
  State<QrRegistroPage> createState() => _QrRegistroPageState();
}

class _QrRegistroPageState extends State<QrRegistroPage> {
  static const _deviceUuidKey = 'bc_walkin_device_id';

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController(text: '+52');
  final _notesCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  String? _serviceId;
  bool _acceptPrivacy = false;
  bool _acceptTos = false;
  bool _acceptCookies = false;

  bool _loadingSalon = true;
  String? _salonName;
  List<Map<String, dynamic>> _services = [];
  String? _loadError;

  bool _submitting = false;
  bool _needsOtp = false;
  String? _submitError;
  bool _done = false;
  bool _redirectToAppInstall = false;

  Future<bool> _confirmInSalon() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Estas en el salon?'),
        content: const Text(
          'Te asignaremos al primer estilista disponible en el horario mas cercano. '
          'Confirma solo si ya estas presente — recibiras tu hora exacta y estilista por WhatsApp '
          'en cuanto el salon te asigne.',
          style: TextStyle(height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Aun no'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEC4899),
              foregroundColor: Colors.white,
            ),
            child: const Text('Si, estoy aqui'),
          ),
        ],
      ),
    );
    return result == true;
  }

  late String _deviceUuid;

  @override
  void initState() {
    super.initState();
    _deviceUuid = _getOrCreateDeviceUuid();
    _loadSalon();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  String _getOrCreateDeviceUuid() {
    final storage = web.window.localStorage;
    final existing = storage.getItem(_deviceUuidKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    // RFC4122 v4
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex2(int b) => b.toRadixString(16).padLeft(2, '0');
    final uuid = '${bytes.sublist(0, 4).map(hex2).join()}-'
        '${bytes.sublist(4, 6).map(hex2).join()}-'
        '${bytes.sublist(6, 8).map(hex2).join()}-'
        '${bytes.sublist(8, 10).map(hex2).join()}-'
        '${bytes.sublist(10, 16).map(hex2).join()}';
    storage.setItem(_deviceUuidKey, uuid);
    return uuid;
  }

  Future<void> _loadSalon() async {
    try {
      final supabase = Supabase.instance.client;
      final biz = await supabase
          .from('businesses')
          .select('id, name, is_active, free_tier_agreements_accepted_at')
          .eq('internal_qr_slug', widget.slug)
          .maybeSingle();
      if (biz == null) {
        setState(() {
          _loadError = 'Salon no encontrado.';
          _loadingSalon = false;
        });
        return;
      }
      if (biz['is_active'] != true ||
          biz['free_tier_agreements_accepted_at'] == null) {
        setState(() {
          _loadError = 'Este salon no tiene el programa de registro activo.';
          _loadingSalon = false;
        });
        return;
      }

      final svc = await supabase
          .from('services')
          .select('id, name, price')
          .eq('business_id', biz['id'])
          .eq('is_active', true)
          .order('name');

      setState(() {
        _salonName = biz['name'] as String?;
        _services = (svc as List).cast<Map<String, dynamic>>();
        _loadingSalon = false;
      });
    } catch (e) {
      setState(() {
        _loadError = 'Error cargando salon: $e';
        _loadingSalon = false;
      });
    }
  }

  bool get _formValid =>
      _nameCtrl.text.trim().isNotEmpty &&
      RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(_phoneCtrl.text.trim()) &&
      _serviceId != null &&
      _acceptPrivacy &&
      _acceptTos &&
      _acceptCookies;

  Future<void> _submit() async {
    if (!_formValid) return;
    // Only gate the FIRST submit on the in-salon confirmation. Once the OTP
    // round-trip starts, we already have the user's commitment.
    if (!_needsOtp) {
      final ok = await _confirmInSalon();
      if (!ok) return;
    }
    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final res = await supabase.functions.invoke(
        'qr-walkin-register',
        body: {
          'business_slug': widget.slug,
          'full_name': _nameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'service_id': _serviceId,
          'client_notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          'device_uuid': _deviceUuid,
          if (_needsOtp) 'otp_code': _otpCtrl.text.trim(),
          'accepted_privacy': _acceptPrivacy,
          'accepted_tos': _acceptTos,
          'accepted_cookies': _acceptCookies,
        },
      );

      final data = res.data;
      if (data is Map) {
        if (data['redirect_to'] == 'bc_signup') {
          setState(() {
            _redirectToAppInstall = true;
            _submitting = false;
          });
          return;
        }
        if (data['needs_otp'] == true) {
          setState(() {
            _needsOtp = true;
            _submitting = false;
          });
          return;
        }
        if (data['success'] == true) {
          setState(() {
            _done = true;
            _submitting = false;
          });
          return;
        }
        if (data['error'] != null) {
          setState(() {
            _submitError = data['error'].toString();
            _submitting = false;
          });
          return;
        }
      }
      setState(() {
        _submitError = 'Respuesta inesperada del servidor.';
        _submitting = false;
      });
    } on FunctionException catch (e) {
      // Surface feature-off and rate-limit errors meaningfully
      final msg = e.details is Map && (e.details as Map)['error'] != null
          ? (e.details as Map)['error'].toString()
          : 'Error de servidor (${e.status})';
      setState(() {
        _submitError = msg;
        _submitting = false;
      });
    } catch (e) {
      setState(() {
        _submitError = 'Error al enviar: $e';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingSalon) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(_loadError!, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Volver a beautycita.com'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_redirectToAppInstall) {
      return _AppDownloadPrompt(salonName: _salonName ?? 'el salon');
    }

    if (_done) {
      return _SuccessPage(salonName: _salonName ?? '');
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _needsOtp ? _buildOtpForm() : _buildMainForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text(
          'Registra tu cita en',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
        ),
        const SizedBox(height: 4),
        Text(
          _salonName ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Nombre completo',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneCtrl,
          decoration: const InputDecoration(
            labelText: 'Telefono (con lada)',
            hintText: '+52...',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[+\d]')),
            LengthLimitingTextInputFormatter(16),
          ],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Pagas en el salon. BeautyCita no cobra ni procesa pagos en este registro.',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: _serviceId,
          decoration: const InputDecoration(
            labelText: 'Servicio',
            border: OutlineInputBorder(),
          ),
          items: _services.map((s) {
            // Price IS shown — the free-tier QR flow doubles as an off-platform
            // income tracker for the salon, so the salon's books reflect what
            // the client agreed to pay.
            final price = s['price'];
            final priceLabel = price != null
                ? ' — \$${(price as num).toStringAsFixed(0)}'
                : '';
            return DropdownMenuItem<String>(
              value: s['id'] as String,
              child: Text('${s['name']}$priceLabel'),
            );
          }).toList(),
          onChanged: (v) => setState(() => _serviceId = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesCtrl,
          decoration: const InputDecoration(
            labelText: 'Notas (opcional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
          maxLength: 200,
        ),
        const SizedBox(height: 12),
        _PrivacyNotice(),
        const SizedBox(height: 12),
        CheckboxListTile(
          value: _acceptPrivacy,
          onChanged: (v) => setState(() => _acceptPrivacy = v ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('He leido el Aviso de Privacidad'),
          dense: true,
        ),
        CheckboxListTile(
          value: _acceptTos,
          onChanged: (v) => setState(() => _acceptTos = v ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Acepto los Terminos y Condiciones'),
          dense: true,
        ),
        CheckboxListTile(
          value: _acceptCookies,
          onChanged: (v) => setState(() => _acceptCookies = v ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Acepto la Politica de Cookies'),
          dense: true,
        ),
        if (_submitError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _submitError!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _formValid && !_submitting ? _submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEC4899),
              foregroundColor: Colors.white,
            ),
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Reservar mi cita', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 40),
        Text(
          'ⓘ beautycita.com',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[500], fontSize: 11),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildOtpForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        const Icon(Icons.message_outlined, size: 48, color: Color(0xFFEC4899)),
        const SizedBox(height: 16),
        const Text(
          'Codigo enviado por WhatsApp',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Ingresa el codigo de 6 digitos que llego a ${_phoneCtrl.text}',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[700], fontSize: 13),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _otpCtrl,
          decoration: const InputDecoration(
            labelText: 'Codigo de 6 digitos',
            border: OutlineInputBorder(),
            counterText: '',
          ),
          keyboardType: TextInputType.number,
          maxLength: 6,
          style: const TextStyle(fontSize: 22, letterSpacing: 6, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
        ),
        if (_submitError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _submitError!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _otpCtrl.text.length == 6 && !_submitting ? _submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEC4899),
              foregroundColor: Colors.white,
            ),
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Verificar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aviso de Privacidad',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[800]),
          ),
          const SizedBox(height: 6),
          Text(
            'BeautyCita procesa estos datos para el salon. Capturamos un identificador de '
            'dispositivo (UUID en tu navegador) y hashes anonimos de IP/navegador solamente para '
            'prevenir fraude. Conforme a la LFPDPPP puedes solicitar acceso, correccion o '
            'eliminacion escribiendo a soporte@beautycita.com. Mas en beautycita.com/privacidad.',
            style: TextStyle(fontSize: 11, height: 1.4, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}

class _SuccessPage extends StatelessWidget {
  final String salonName;
  const _SuccessPage({required this.salonName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
              const SizedBox(height: 20),
              const Text(
                'Gracias',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Recibiras tu confirmacion en breve cuando el salon asigne tu estilista y horario.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.4),
              ),
              const SizedBox(height: 28),
              Text(
                salonName,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFEC4899)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppDownloadPrompt extends StatelessWidget {
  final String salonName;
  const _AppDownloadPrompt({required this.salonName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.phone_android_rounded, size: 64, color: Color(0xFFEC4899)),
              const SizedBox(height: 20),
              const Text(
                'Descarga BeautyCita',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Para reservar en $salonName, descarga la aplicacion BeautyCita. '
                'La primera cita se confirma en segundos.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.4),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () {
                  web.window.location.href = 'https://beautycita.com/download';
                },
                icon: const Icon(Icons.download_rounded),
                label: const Text('Descargar App'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEC4899),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
