import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita_core/supabase.dart';

import '../config/breakpoints.dart';
import '../config/router.dart';
import '../providers/auth_provider.dart';

/// Salon registration page — pre-filled from discovered_salons data.
///
/// URL: /registro/{salonId}
/// Public route (no auth required — the form handles auth at step 2).
class RegistroPage extends ConsumerStatefulWidget {
  const RegistroPage({super.key, required this.salonId});

  final String salonId;

  @override
  ConsumerState<RegistroPage> createState() => _RegistroPageState();
}

class _RegistroPageState extends ConsumerState<RegistroPage> {
  // ── State ──────────────────────────────────────────────────────────────────
  int _currentStep = 0;
  bool _loading = true;
  bool _notFound = false;
  // Step 1: Business info
  final _bizNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _imageUrl;

  // Step 2: Auth
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _authFormKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _authComplete = false;

  // Step 3: Services
  final Set<String> _selectedServices = {};

  // Brand colors (matching landing page)
  static const _deepRose = Color(0xFF990033);
  static const _lightRose = Color(0xFFC2185B);
  static const _serviceCategories = [
    ('Corte', Icons.content_cut),
    ('Color', Icons.palette_outlined),
    ('Manicure', Icons.back_hand_outlined),
    ('Pedicure', Icons.spa_outlined),
    ('Pestanas', Icons.visibility_outlined),
    ('Cejas', Icons.face_retouching_natural),
    ('Maquillaje', Icons.brush_outlined),
    ('Facial', Icons.face_outlined),
    ('Masaje', Icons.self_improvement_outlined),
    ('Depilacion', Icons.auto_fix_high_outlined),
    ('Barberia', Icons.face_2_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _fetchSalonData();
  }

  @override
  void dispose() {
    _bizNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _fetchSalonData() async {
    if (!BCSupabase.isInitialized) {
      setState(() {
        _loading = false;
        _notFound = true;
      });
      return;
    }
    try {
      final data = await BCSupabase.client
          .from(BCTables.discoveredSalons)
          .select()
          .eq('id', widget.salonId)
          .maybeSingle();

      if (data == null) {
        setState(() {
          _loading = false;
          _notFound = true;
        });
        return;
      }

      _bizNameController.text = (data['business_name'] as String?) ?? '';
      _addressController.text = (data['location_address'] as String?) ?? '';
      _cityController.text = (data['location_city'] as String?) ?? '';
      _phoneController.text = (data['phone'] as String?) ?? '';
      _imageUrl = data['feature_image_url'] as String?;

      setState(() => _loading = false);
    } catch (_) {
      setState(() {
        _loading = false;
        _notFound = true;
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final isMobile = w < 600;
          final isDesktop = WebBreakpoints.isDesktop(w);
          final hPad = isMobile ? 16.0 : (isDesktop ? 80.0 : 32.0);

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(context, isMobile, hPad),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: CircularProgressIndicator(),
                  )
                else if (_notFound)
                  _buildNotFound(context, isMobile, hPad)
                else
                  _buildForm(context, isMobile, isDesktop, hPad),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, bool isMobile, double hPad) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF660033), _deepRose, _lightRose],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: hPad,
        vertical: isMobile ? 24 : 40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => context.go(WebRoutes.home),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text(
                'BeautyCita',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 20 : 24,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Registro de Salon',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                  fontSize: isMobile ? 18 : 24,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Registra tu negocio en menos de 2 minutos',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: isMobile ? 13 : 14,
                ),
          ),
        ],
      ),
    );
  }

  // ── Not Found ──────────────────────────────────────────────────────────────

  Widget _buildNotFound(BuildContext context, bool isMobile, double hPad) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 60),
      child: Column(
        children: [
          Icon(Icons.store_outlined,
              size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'Salon no encontrado',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'El enlace que usaste no es valido o el salon ya fue registrado.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => context.go(WebRoutes.auth),
            child: const Text('Registrarse manualmente'),
          ),
        ],
      ),
    );
  }

  // ── Form ───────────────────────────────────────────────────────────────────

  Widget _buildForm(
      BuildContext context, bool isMobile, bool isDesktop, double hPad) {
    final maxWidth = isDesktop ? 640.0 : double.infinity;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: hPad,
        vertical: isMobile ? 20 : 40,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            children: [
              _buildProgressIndicator(context, isMobile),
              const SizedBox(height: 24),
              _buildStepContent(context, isMobile),
            ],
          ),
        ),
      ),
    );
  }

  // ── Progress Indicator ─────────────────────────────────────────────────────

  Widget _buildProgressIndicator(BuildContext context, bool isMobile) {
    final labels = ['Negocio', 'Cuenta', 'Servicios', 'Listo'];
    return Row(
      children: List.generate(labels.length, (i) {
        final isActive = i == _currentStep;
        final isComplete = i < _currentStep;
        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  if (i > 0)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isComplete || isActive
                            ? _lightRose
                            : Colors.grey.shade300,
                      ),
                    ),
                  Container(
                    width: isMobile ? 28 : 32,
                    height: isMobile ? 28 : 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isComplete
                          ? _lightRose
                          : isActive
                              ? _deepRose
                              : Colors.grey.shade300,
                    ),
                    child: Center(
                      child: isComplete
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                color:
                                    isActive ? Colors.white : Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                                fontSize: isMobile ? 12 : 14,
                              ),
                            ),
                    ),
                  ),
                  if (i < labels.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isComplete
                            ? _lightRose
                            : Colors.grey.shade300,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                labels[i],
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isActive || isComplete
                          ? _deepRose
                          : Colors.grey.shade500,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.w400,
                      fontSize: isMobile ? 10 : 11,
                    ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ── Step Content ───────────────────────────────────────────────────────────

  Widget _buildStepContent(BuildContext context, bool isMobile) {
    switch (_currentStep) {
      case 0:
        return _buildStep1(context, isMobile);
      case 1:
        return _buildStep2(context, isMobile);
      case 2:
        return _buildStep3(context, isMobile);
      case 3:
        return _buildStep4(context, isMobile);
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Step 1: Confirm Business Info ──────────────────────────────────────────

  Widget _buildStep1(BuildContext context, bool isMobile) {
    final theme = Theme.of(context);
    return _stepCard(
      context: context,
      isMobile: isMobile,
      title: 'Confirma la informacion de tu negocio',
      subtitle: 'Verifica que los datos sean correctos. Puedes editarlos.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_imageUrl != null && _imageUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _imageUrl!,
                height: isMobile ? 140 : 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: isMobile ? 140 : 180,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.store,
                      size: 48, color: Colors.grey.shade400),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          TextField(
            controller: _bizNameController,
            decoration: const InputDecoration(
              labelText: 'Nombre del negocio',
              prefixIcon: Icon(Icons.store_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Direccion',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _cityController,
            decoration: const InputDecoration(
              labelText: 'Ciudad',
              prefixIcon: Icon(Icons.location_city_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Telefono',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _validateStep1() ? _goToStep2 : null,
            child: const Text('Continuar'),
          ),
          const SizedBox(height: 8),
          Text(
            'Paso 1 de 4',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  bool _validateStep1() {
    return _bizNameController.text.trim().isNotEmpty &&
        _cityController.text.trim().isNotEmpty;
  }

  void _goToStep2() {
    setState(() => _currentStep = 1);
  }

  // ── Step 2: Create Account ─────────────────────────────────────────────────

  Widget _buildStep2(BuildContext context, bool isMobile) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);

    return _stepCard(
      context: context,
      isMobile: isMobile,
      title: 'Crea tu cuenta',
      subtitle: 'Con tu cuenta administraras citas, pagos y clientes.',
      child: Form(
        key: _authFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_authComplete) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Cuenta creada exitosamente',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => setState(() => _currentStep = 2),
                child: const Text('Continuar'),
              ),
            ] else ...[
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tu nombre',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Correo electronico',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
                  if (!v.contains('@') || !v.contains('.')) {
                    return 'Correo no valido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Contrasena',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Ingresa una contrasena';
                  if (v.length < 6) return 'Minimo 6 caracteres';
                  return null;
                },
              ),
              if (authState.errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    authState.errorMessage!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.red.shade700),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: authState.isLoading ? null : _handleSignUp,
                child: authState.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Crear cuenta'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() => _currentStep = 0),
                child: const Text('Volver'),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Paso 2 de 4',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSignUp() async {
    if (!_authFormKey.currentState!.validate()) return;

    final notifier = ref.read(authProvider.notifier);
    final success = await notifier.signUpWithEmail(
      _emailController.text.trim(),
      _passwordController.text,
      _nameController.text.trim(),
    );

    if (success && mounted) {
      setState(() => _authComplete = true);
    }
  }

  // ── Step 3: Add Services ───────────────────────────────────────────────────

  Widget _buildStep3(BuildContext context, bool isMobile) {
    final theme = Theme.of(context);
    return _stepCard(
      context: context,
      isMobile: isMobile,
      title: 'Que servicios ofreces?',
      subtitle: 'Selecciona las categorias principales. Puedes agregar mas despues.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _serviceCategories.map((entry) {
              final (label, icon) = entry;
              final selected = _selectedServices.contains(label);
              return FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon,
                        size: 18,
                        color: selected ? _deepRose : Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(label),
                  ],
                ),
                selected: selected,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _selectedServices.add(label);
                    } else {
                      _selectedServices.remove(label);
                    }
                  });
                },
                selectedColor: _lightRose.withValues(alpha: 0.15),
                checkmarkColor: _deepRose,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _handleFinishRegistration,
            child: Text(_selectedServices.isEmpty
                ? 'Agregar mas despues'
                : 'Finalizar registro'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() => _currentStep = 1),
            child: const Text('Volver'),
          ),
          const SizedBox(height: 8),
          Text(
            'Paso 3 de 4',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleFinishRegistration() async {
    if (!BCSupabase.isInitialized) return;

    final user = BCSupabase.client.auth.currentUser;
    if (user == null) return;

    try {
      // Create the business record linked to this user and discovered salon
      await BCSupabase.client.from(BCTables.businesses).insert({
        'owner_id': user.id,
        'name': _bizNameController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'phone': _phoneController.text.trim(),
        'discovered_salon_id': widget.salonId,
        'photo_url': _imageUrl,
        'service_categories': _selectedServices.toList(),
      });

      // Update the user role to 'business'
      await BCSupabase.client.from(BCTables.profiles).update({
        'role': 'business',
      }).eq('id', user.id);

      // Mark discovered salon as converted
      await BCSupabase.client
          .from(BCTables.discoveredSalons)
          .update({'status': 'converted'}).eq('id', widget.salonId);

      if (mounted) {
        setState(() => _currentStep = 3);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  // ── Step 4: Success ────────────────────────────────────────────────────────

  Widget _buildStep4(BuildContext context, bool isMobile) {
    return _stepCard(
      context: context,
      isMobile: isMobile,
      title: '',
      subtitle: '',
      showHeader: false,
      child: Column(
        children: [
          const SizedBox(height: 16),
          _ConfettiIcon(size: isMobile ? 80 : 100),
          const SizedBox(height: 24),
          Text(
            'Tu salon esta registrado en BeautyCita!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 20 : 24,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bienvenido, ${_bizNameController.text.trim()}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => context.go(WebRoutes.negocio),
            icon: const Icon(Icons.dashboard_outlined),
            label: const Text('Ir al panel de negocio'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Step Card Wrapper ──────────────────────────────────────────────────────

  Widget _stepCard({
    required BuildContext context,
    required bool isMobile,
    required String title,
    required String subtitle,
    required Widget child,
    bool showHeader = true,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader) ...[
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: isMobile ? 16 : 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
          ],
          child,
        ],
      ),
    );
  }
}

// ── Confetti / Success Icon ──────────────────────────────────────────────────

class _ConfettiIcon extends StatelessWidget {
  const _ConfettiIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xFFec4899),
      Color(0xFF9333ea),
      Color(0xFF3b82f6),
      Color(0xFFFFB300),
      Color(0xFF10B981),
      Color(0xFFEF4444),
    ];

    return SizedBox(
      width: size * 1.6,
      height: size * 1.6,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Confetti dots
          ...List.generate(12, (i) {
            final rng = Random(i * 42);
            final angle = (i / 12) * 2 * pi;
            final radius = size * 0.55 + rng.nextDouble() * size * 0.2;
            final dotSize = 6.0 + rng.nextDouble() * 6;
            return Positioned(
              left: size * 0.8 + cos(angle) * radius - dotSize / 2,
              top: size * 0.8 + sin(angle) * radius - dotSize / 2,
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: colors[i % colors.length],
                  shape: i % 3 == 0
                      ? BoxShape.rectangle
                      : BoxShape.circle,
                  borderRadius:
                      i % 3 == 0 ? BorderRadius.circular(2) : null,
                ),
              ),
            );
          }),
          // Center check
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: size * 0.55,
            ),
          ),
        ],
      ),
    );
  }
}
