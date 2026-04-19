import 'dart:async';
import 'package:beautycita/config/app_transitions.dart';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita/widgets/bc_image_picker_sheet.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/config/theme_extension.dart';
import 'package:beautycita/providers/auth_provider.dart';
import 'package:beautycita/providers/profile_provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:beautycita/services/lightx_service.dart';
import 'package:beautycita/services/media_service.dart';
import 'package:beautycita/providers/security_provider.dart';
import 'package:beautycita/services/username_generator.dart';
import 'package:beautycita/services/username_validator.dart';
import 'package:beautycita/widgets/settings_widgets.dart';
import 'package:beautycita/providers/admin_provider.dart';
import 'package:beautycita/providers/business_provider.dart';
import 'package:beautycita/providers/feature_toggle_provider.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:beautycita/services/supabase_client.dart';
import 'package:beautycita/services/toast_service.dart';
import 'package:beautycita/config/fonts.dart';

// ── Profile stat providers ──

final _profileSaldoProvider = FutureProvider<double>((ref) async {
  final userId = SupabaseClientService.currentUserId;
  if (userId == null) return 0;
  final data = await SupabaseClientService.client
      .from(BCTables.profiles)
      .select('saldo')
      .eq('id', userId)
      .maybeSingle();
  return (data?['saldo'] as num?)?.toDouble() ?? 0;
});

final _profileBookingCountProvider = FutureProvider<int>((ref) async {
  final userId = SupabaseClientService.currentUserId;
  if (userId == null) return 0;
  final data = await SupabaseClientService.client
      .from(BCTables.appointments)
      .select('id')
      .eq('user_id', userId)
      .inFilter('status', ['completed', 'confirmed']);
  return (data as List).length;
});

// ── AI Avatar Style Model ──

class _AIAvatarStyle {
  final String id;
  final String name;
  final IconData icon;
  final String prompt;
  final Color color;
  final List<Color> gradientColors;

  const _AIAvatarStyle({
    required this.id,
    required this.name,
    required this.icon,
    required this.prompt,
    required this.color,
    required this.gradientColors,
  });
}

const _aiAvatarStyles = [
  _AIAvatarStyle(
    id: 'glam',
    name: 'Glam',
    icon: Icons.auto_awesome_outlined,
    prompt: 'Glamorous beauty portrait, studio lighting, radiant skin, elegant makeup, fashion editorial style',
    color: Color(0xFFEB0000),
    gradientColors: [Color(0xFFEB0000), Color(0xFF95008A), Color(0xFF3300FC)],
  ),
  _AIAvatarStyle(
    id: 'cyberpunk',
    name: 'Cyberpunk',
    icon: Icons.electric_bolt_outlined,
    prompt: 'Cyberpunk sci-fi portrait, neon lights, futuristic style, holographic effects, dystopian aesthetic, tech vibes',
    color: Color(0xFF0C0C6D),
    gradientColors: [Color(0xFF0C0C6D), Color(0xFFDE512B), Color(0xFF98D0C1), Color(0xFF5BB226), Color(0xFF023C0D)],
  ),
  _AIAvatarStyle(
    id: 'fantasia',
    name: 'Fantasia',
    icon: Icons.nightlight_outlined,
    prompt: 'Fantasy mythical portrait, ethereal glow, magical aura, enchanted forest background, fairy tale aesthetic',
    color: Color(0xFF8BDEDA),
    gradientColors: [Color(0xFF8BDEDA), Color(0xFF43ADD0), Color(0xFF998EE0), Color(0xFFE17DC2), Color(0xFFEF9393)],
  ),
  _AIAvatarStyle(
    id: 'clasico',
    name: 'Clasico',
    icon: Icons.photo_outlined,
    prompt: 'Classic timeless portrait, warm tones, soft lighting, professional headshot, refined elegance',
    color: Color(0xFFC31432),
    gradientColors: [Color(0xFFC31432), Color(0xFF240B36)],
  ),
];

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _editingName = false;
  bool _editingUsername = false;
  bool _usernameAvailable = true;
  bool _checkingUsername = false;
  String? _usernameError;
  List<String> _usernameSuggestions = [];
  Timer? _usernameDebounce;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _usernameDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final profile = ref.watch(profileProvider);
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<BCThemeExtension>()!;

    // Profile completion calculation
    int completedFields = 0;
    const totalFields = 4;
    if (profile.fullName != null) completedFields++;
    if (profile.phone != null) completedFields++;
    if (profile.birthday != null) completedFields++;
    if (profile.gender != null) completedFields++;
    final completionPercent = (completedFields / totalFields * 100).round();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Perfil'),
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.screenPaddingHorizontal,
          vertical: AppConstants.paddingMD,
        ),
        children: [
          // ── Avatar Hero Card ──
          _buildAvatarHeroCard(
            context, authState, profile, textTheme, cs, ext, completionPercent,
          ),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Personal Info Card ──
          const SectionHeader(label: 'Informacion personal'),
          const SizedBox(height: AppConstants.paddingSM),
          _buildPersonalInfoCard(context, profile, textTheme, cs, ext),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Account Stats ──
          const SizedBox(height: AppConstants.paddingLG),
          const SectionHeader(label: 'Mi cuenta'),
          const SizedBox(height: AppConstants.paddingSM),
          _buildAccountStats(context, cs, ext, textTheme),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Quick Links ──
          _buildQuickLinks(context, cs, ext, textTheme),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Register Salon CTA ──
          _buildRegisterSalonCTA(context, cs, ext, textTheme),

          const SizedBox(height: AppConstants.paddingLG),
        ],
      ),
    );
  }

  // ── Avatar Hero Card ──

  Widget _buildAvatarHeroCard(
    BuildContext context,
    dynamic authState,
    dynamic profile,
    TextTheme textTheme,
    ColorScheme cs,
    BCThemeExtension ext,
    int completionPercent,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(AppConstants.paddingLG),
      decoration: BoxDecoration(
        gradient: ext.primaryGradient,
        borderRadius: BorderRadius.circular(AppConstants.radiusLG),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar with camera badge and completion ring
          GestureDetector(
            onTap: _showAvatarOptions,
            child: SizedBox(
              width: 108,
              height: 108,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Completion ring
                  SizedBox(
                    width: 108,
                    height: 108,
                    child: CircularProgressIndicator(
                      value: completionPercent / 100,
                      strokeWidth: 3,
                      backgroundColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation(cs.onPrimary),
                    ),
                  ),
                  // Avatar
                  CircleAvatar(
                    key: ValueKey(profile.avatarUrl),
                    radius: 46,
                    backgroundColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
                    backgroundImage: profile.avatarUrl != null
                        ? NetworkImage(profile.avatarUrl!)
                        : null,
                    child: profile.avatarUrl == null
                        ? Icon(Icons.person_outline, size: 46,
                            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7))
                        : null,
                  ),
                  // Camera badge
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onPrimary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(Icons.camera_alt_outlined,
                          size: 16, color: cs.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppConstants.paddingSM),

          // Username (tap to edit)
          if (_editingUsername)
            _buildUsernameEditorWhite(textTheme)
          else
            GestureDetector(
              onTap: _startEditingUsername,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    authState.username ?? 'Usuario',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.edit_outlined, size: 16,
                      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)),
                ],
              ),
            ),

          const SizedBox(height: 4),

          // Completion percentage text
          Text(
            '$completionPercent% completado',
            style: textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsernameEditorWhite(TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingSM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _usernameController,
                  autofocus: true,
                  maxLength: 30,
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                  decoration: InputDecoration(
                    hintText: 'Nombre de usuario',
                    hintStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.5)),
                    isDense: true,
                    counterText: '',
                    errorText: _usernameError,
                    errorStyle: const TextStyle(color: Colors.yellowAccent),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.5)),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.onPrimary),
                    ),
                    suffixIcon: _checkingUsername
                        ? Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary),
                            ),
                          )
                        : _usernameController.text.length >= 3
                            ? Icon(
                                _usernameAvailable
                                    ? Icons.check_circle_outlined
                                    : Icons.cancel_outlined,
                                color: _usernameAvailable
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                                size: 20,
                              )
                            : null,
                  ),
                  onChanged: _onUsernameChanged,
                  onSubmitted: (_) => _saveUsername(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.check_outlined, color: Theme.of(context).colorScheme.onPrimary),
                onPressed: _usernameAvailable && _usernameError == null
                    ? _saveUsername
                    : null,
              ),
              IconButton(
                icon: Icon(Icons.close_outlined,
                    color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)),
                onPressed: () => setState(() => _editingUsername = false),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingXS),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: _usernameSuggestions
                .map(
                  (s) => ActionChip(
                    label: Text(s, style: TextStyle(
                      fontSize: 12, color: Theme.of(context).colorScheme.onPrimary)),
                    onPressed: () {
                      _usernameController.text = s;
                      _onUsernameChanged(s);
                    },
                    backgroundColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppConstants.paddingXS),
        ],
      ),
    );
  }

  // ── Personal Info Card ──

  Widget _buildPersonalInfoCard(
    BuildContext context,
    dynamic profile,
    TextTheme textTheme,
    ColorScheme cs,
    BCThemeExtension ext,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: ext.cardBorderColor),
      ),
      child: Column(
        children: [
          // Name
          if (_editingName)
            _buildNameEditor(textTheme, cs)
          else
            _infoRow(
              icon: Icons.badge_outlined,
              iconColor: profile.fullName != null
                  ? ext.successColor
                  : cs.primary,
              label: 'Nombre',
              value: profile.fullName ?? 'Agregar nombre',
              valueIsPlaceholder: profile.fullName == null,
              trailing: profile.fullName != null
                  ? Icon(Icons.check_circle_outlined, size: 18,
                      color: ext.successColor)
                  : Text('Agregar', style: textTheme.bodySmall?.copyWith(
                      color: cs.primary, fontWeight: FontWeight.w600)),
              onTap: () {
                _nameController.text = profile.fullName ?? '';
                setState(() => _editingName = true);
              },
              showDivider: true,
            ),

          // Birthday
          _infoRow(
            icon: Icons.cake_outlined,
            iconColor: profile.birthday != null
                ? ext.successColor
                : cs.primary,
            label: 'Fecha de nacimiento',
            value: profile.birthday != null
                ? DateFormat('d MMM yyyy', 'es').format(profile.birthday!)
                : 'Agregar',
            valueIsPlaceholder: profile.birthday == null,
            trailing: profile.birthday != null
                ? Icon(Icons.check_circle_outlined, size: 18,
                    color: ext.successColor)
                : null,
            onTap: () => _showBirthdayPicker(context),
            showDivider: true,
          ),

          // Gender
          _infoRow(
            icon: Icons.person_outline_rounded,
            iconColor: profile.gender != null
                ? ext.successColor
                : cs.primary,
            label: 'Genero',
            value: profile.gender != null
                ? _genderLabel(profile.gender!)
                : 'Agregar',
            valueIsPlaceholder: profile.gender == null,
            trailing: profile.gender != null
                ? Icon(Icons.check_circle_outlined, size: 18,
                    color: ext.successColor)
                : null,
            onTap: () => _showGenderSheet(context),
            showDivider: false,
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    bool valueIsPlaceholder = false,
    Widget? trailing,
    VoidCallback? onTap,
    bool showDivider = true,
  }) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: showDivider
              ? null
              : BorderRadius.vertical(
                  bottom: Radius.circular(AppConstants.radiusMD)),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingMD,
              vertical: AppConstants.paddingSM + 4,
            ),
            child: Row(
              children: [
                // Icon box
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppConstants.radiusXS),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: AppConstants.paddingSM + 4),
                // Label + value
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontSize: 11,
                      )),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: valueIsPlaceholder
                              ? cs.onSurface.withValues(alpha: 0.4)
                              : cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AppConstants.paddingSM),
                  trailing,
                ],
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: AppConstants.paddingMD + 32 + AppConstants.paddingSM + 4,
            endIndent: AppConstants.paddingMD,
            color: ext.cardBorderColor,
          ),
      ],
    );
  }

  Widget _buildNameEditor(TextTheme textTheme, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMD,
        vertical: AppConstants.paddingSM,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppConstants.radiusXS),
            ),
            child: Icon(Icons.badge_outlined, size: 18, color: cs.primary),
          ),
          const SizedBox(width: AppConstants.paddingSM + 4),
          Expanded(
            child: TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Tu nombre completo',
                isDense: true,
              ),
              onSubmitted: (_) => _saveName(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.check_outlined, color: cs.primary),
            onPressed: _saveName,
          ),
          IconButton(
            icon: Icon(Icons.close_outlined, color: cs.onSurface.withValues(alpha: 0.5)),
            onPressed: () => setState(() => _editingName = false),
          ),
        ],
      ),
    );
  }

  // ── Account Stats ──

  Widget _buildAccountStats(
    BuildContext context, ColorScheme cs, BCThemeExtension ext, TextTheme textTheme,
  ) {
    // Query saldo
    final saldoAsync = ref.watch(_profileSaldoProvider);
    final saldo = saldoAsync.valueOrNull ?? 0.0;

    // Count bookings
    final bookingsAsync = ref.watch(_profileBookingCountProvider);
    final totalBookings = bookingsAsync.valueOrNull ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: ext.cardBorderColor),
      ),
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      child: Row(
        children: [
          Expanded(
            child: _statColumn(
              icon: Icons.calendar_today_outlined,
              label: 'Citas',
              value: '$totalBookings',
              color: cs.primary,
            ),
          ),
          Container(width: 1, height: 40, color: ext.cardBorderColor),
          Expanded(
            child: _statColumn(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Saldo',
              value: '\$${saldo.toStringAsFixed(0)}',
              color: const Color(0xFF059669),
            ),
          ),
          Container(width: 1, height: 40, color: ext.cardBorderColor),
          Expanded(
            child: _statColumn(
              icon: Icons.star_outline,
              label: 'Miembro desde',
              value: _memberSince(),
              color: const Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statColumn({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: GoogleFonts.nunito(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
      ],
    );
  }

  String _memberSince() {
    // Use auth state creation — profiles don't expose created_at directly
    return '2026';
  }

  // ── Quick Links ──

  Widget _buildQuickLinks(
    BuildContext context, ColorScheme cs, BCThemeExtension ext, TextTheme textTheme,
  ) {
    return Column(
      children: [
        _quickLinkTile(
          icon: Icons.receipt_long_outlined,
          label: 'Mis citas',
          color: cs.primary,
          onTap: () => context.push('/my-bookings'),
        ),
        _quickLinkTile(
          icon: Icons.credit_card_outlined,
          label: 'Metodos de pago',
          color: const Color(0xFF8B5CF6),
          onTap: () => context.push('/settings/payment-methods'),
        ),
        _quickLinkTile(
          icon: Icons.shield_outlined,
          label: 'Seguridad',
          color: const Color(0xFFEF4444),
          onTap: () => context.push('/settings/security'),
        ),
        _quickLinkTile(
          icon: Icons.settings_outlined,
          label: 'Preferencias',
          color: const Color(0xFF6B7280),
          onTap: () => context.push('/settings/preferences'),
        ),
      ],
    );
  }

  Widget _quickLinkTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          border: Border.all(color: ext.cardBorderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.chevron_right, size: 20, color: cs.onSurface.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

  // ── Register Salon CTA ──

  Widget _buildRegisterSalonCTA(
    BuildContext context, ColorScheme cs, BCThemeExtension ext, TextTheme textTheme,
  ) {
    final toggles = ref.watch(featureTogglesProvider);
    if (!toggles.isEnabled('enable_salon_registration')) {
      return const SizedBox.shrink();
    }

    final role = ref.watch(userRoleProvider).valueOrNull;
    if (role == 'admin' || role == 'superadmin' || role == 'stylist') {
      return const SizedBox.shrink();
    }

    final isOwner = ref.watch(isBusinessOwnerProvider).valueOrNull ?? false;
    if (isOwner) return const SizedBox.shrink();

    final appOpens = ref.watch(appOpenCountProvider).valueOrNull ?? 0;
    if (appOpens < 10) return const SizedBox.shrink();

    final phoneVerified = ref.watch(profileProvider).hasVerifiedPhone;
    final emailVerified = ref.watch(securityProvider).isEmailConfirmed;
    final canRegister = phoneVerified && emailVerified;

    return GestureDetector(
      onTap: canRegister
          ? () => context.push('/registro')
          : () => ToastService.showWarning(
              'Para registrar tu salon necesitas verificar tu numero de telefono '
              'y confirmar tu email. Ve a Ajustes > Seguridad para completar la verificacion.',
            ),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        decoration: BoxDecoration(
          gradient: ext.primaryGradient,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppConstants.radiusSM),
              ),
              child: Icon(Icons.home_outlined, color: Theme.of(context).colorScheme.onPrimary, size: 22),
            ),
            const SizedBox(width: AppConstants.paddingSM + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Registra tu salon', style: textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.w700)),
                  Text('Lleva tu negocio al siguiente nivel',
                    style: textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_outlined,
                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8)),
          ],
        ),
      ),
    );
  }

  // ── Username editing ──

  void _startEditingUsername() {
    final current = ref.read(authStateProvider).username ?? '';
    _usernameController.text = current;
    _usernameSuggestions =
        UsernameGenerator.generateSuggestions(count: 4, withSuffix: false);
    setState(() {
      _editingUsername = true;
      _usernameError = null;
      _usernameAvailable = true;
      _checkingUsername = false;
    });
  }

  // Old _buildUsernameEditor removed — replaced by _buildUsernameEditorWhite

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    final trimmed = value.trim();

    // Validate format, reserved words, and profanity
    final error = UsernameValidator.validate(trimmed);
    if (error != null) {
      setState(() {
        _usernameError = error;
        _usernameAvailable = false;
        _checkingUsername = false;
      });
      return;
    }

    setState(() {
      _usernameError = null;
      _checkingUsername = true;
    });

    // Debounced uniqueness check
    _usernameDebounce = Timer(const Duration(milliseconds: 500), () async {
      final available = await ref
          .read(profileProvider.notifier)
          .checkUsernameAvailable(trimmed);
      if (!mounted) return;
      setState(() {
        _usernameAvailable = available;
        _checkingUsername = false;
        if (!available) _usernameError = 'Ya esta en uso';
      });
    });
  }

  Future<void> _saveUsername() async {
    final username = _usernameController.text.trim();
    if (UsernameValidator.validate(username) != null || !_usernameAvailable) return;

    final success =
        await ref.read(profileProvider.notifier).updateUsername(username);
    if (!mounted) return;

    if (success) {
      await ref.read(authStateProvider.notifier).updateUsername(username);
      if (!mounted) return;
      setState(() => _editingUsername = false);
      ToastService.showSuccess('Usuario actualizado');
    } else {
      ToastService.showError('Error al actualizar usuario');
    }
  }

  // ── Avatar options ──

  void _showAvatarOptions() {
    showBurstBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppConstants.radiusXL)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.paddingLG,
              AppConstants.paddingMD,
              AppConstants.paddingLG,
              AppConstants.paddingLG,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildSheetHeader(ctx, 'Cambiar foto de perfil'),
                SettingsTile(
                  icon: Icons.photo_library_outlined,
                  label: 'Subir foto',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndCropAvatar(useAI: false);
                  },
                ),
                if (ref.read(featureTogglesProvider).isEnabled('enable_ai_avatars'))
                  SettingsTile(
                    icon: Icons.auto_awesome_outlined,
                    label: 'Crear avatar IA',
                    iconColor: Colors.deepPurple,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndCropAvatar(useAI: true);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndCropAvatar({required bool useAI}) async {
    final result = await showBCImagePicker(
      context: context,
      ref: ref,
    );
    if (result == null || !mounted) return;

    // Show crop editor with the picked image bytes
    final cropped = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _AvatarCropEditor(imageBytes: result.bytes),
      ),
    );
    if (cropped == null || !mounted) return;

    if (useAI) {
      await _showAIStylePicker(cropped);
    } else {
      await _uploadCroppedAvatar(cropped);
    }
  }

  Future<void> _showAIStylePicker(Uint8List croppedBytes) async {
    final selectedStyle = await showModalBottomSheet<_AIAvatarStyle>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppConstants.radiusXL)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.paddingLG,
              AppConstants.paddingMD,
              AppConstants.paddingLG,
              AppConstants.paddingLG,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildSheetHeader(ctx, 'Elige un estilo'),
                ..._aiAvatarStyles.map((style) => ListTile(
                      leading: Icon(style.icon, color: style.color, size: 28),
                      title: Text(
                        style.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: Icon(Icons.chevron_right_outlined,
                          color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5)),
                      onTap: () => Navigator.pop(ctx, style),
                    )),
              ],
            ),
          ),
        );
      },
    );

    if (selectedStyle == null || !mounted) return;
    await _processAIAvatar(croppedBytes, selectedStyle.prompt);
  }

  Future<void> _uploadCroppedAvatar(Uint8List bytes) async {
    ToastService.showInfo('Subiendo foto (${(bytes.length / 1024).toStringAsFixed(0)} KB)...');

    final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.png';
    final url =
        await ref.read(profileProvider.notifier).uploadAvatar(bytes, fileName);
    if (!mounted) return;

    if (url != null) {
      ToastService.showSuccess('Foto actualizada');
    } else {
      final error = ref.read(profileProvider).error ?? 'Error desconocido';
      ToastService.showError('Error: $error');
    }
  }

  Future<void> _processAIAvatar(Uint8List croppedBytes, String stylePrompt) async {
    if (!mounted) return;
    if (kDebugMode) debugPrint('[Avatar] Starting AI avatar creation — ${croppedBytes.length} bytes, style: $stylePrompt');
    showBurstDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Creando tu avatar...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      if (kDebugMode) debugPrint('[Avatar] Calling LightX edge function (headshot)...');
      final lightx = LightXService();
      final resultUrl = await lightx.processTryOn(
        imageBytes: croppedBytes,
        tryOnTypeId: 'headshot',
        stylePrompt: stylePrompt,
      );
      if (kDebugMode) debugPrint('[Avatar] LightX returned result: $resultUrl');

      // Download the result image so we can upload to permanent storage
      if (kDebugMode) debugPrint('[Avatar] Downloading result image...');
      final response = await http.get(Uri.parse(resultUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download AI result (HTTP ${response.statusCode})');
      }
      final resultBytes = response.bodyBytes;
      if (kDebugMode) debugPrint('[Avatar] Downloaded ${resultBytes.length} bytes');

      if (!mounted) return;

      // Upload to Supabase storage as permanent avatar
      if (kDebugMode) debugPrint('[Avatar] Uploading to Supabase storage...');
      final fileName = 'avatar_ai_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final permanentUrl = await ref
          .read(profileProvider.notifier)
          .uploadAvatar(resultBytes, fileName);

      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading

      if (permanentUrl == null) {
        throw Exception('Failed to upload avatar');
      }
      if (kDebugMode) debugPrint('[Avatar] Avatar saved: $permanentUrl');

      // Save to user_media for media library
      try {
        final mediaService = MediaService();
        await mediaService.saveLightXResult(
          resultUrl: permanentUrl,
          toolType: 'headshot',
          stylePrompt: stylePrompt,
        );
      } catch (e) {
        if (kDebugMode) debugPrint('[Profile] saveLightXResult failed (non-critical): $e');
      }

      ToastService.showSuccess('Avatar IA creado');
    } catch (e, st) {
      if (kDebugMode) debugPrint('[Avatar] ERROR: $e');
      if (kDebugMode) debugPrint('[Avatar] Stack trace: $st');
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, st);
    }
  }

  // ── Birthday ──

  Future<void> _showBirthdayPicker(BuildContext context) async {
    final current = ref.read(profileProvider).birthday;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)),
      locale: const Locale('es'),
    );
    if (picked != null && mounted) {
      await ref.read(profileProvider.notifier).updateBirthday(picked);
      if (ref.read(profileProvider).error == null) {
        ToastService.showSuccess('Fecha de nacimiento guardada');
      }
    }
  }

  // ── Gender ──

  String _genderLabel(String gender) {
    switch (gender) {
      case 'female': return 'Mujer';
      case 'male': return 'Hombre';
      case 'non_binary': return 'No binario';
      case 'prefer_not_say': return 'Prefiero no decir';
      default: return gender;
    }
  }

  void _showGenderSheet(BuildContext context) {
    showBurstBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildSheetHeader(context, 'Genero'),
                for (final g in ['female', 'male', 'non_binary', 'prefer_not_say'])
                  OptionTile(
                    emoji: g == 'female' ? '♀' : g == 'male' ? '♂' : g == 'non_binary' ? '⚧' : '—',
                    label: _genderLabel(g),
                    subtitle: '',
                    selected: ref.read(profileProvider).gender == g,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await ref.read(profileProvider.notifier).updateGender(g);
                      if (ref.read(profileProvider).error == null) {
                        ToastService.showSuccess('Genero guardado');
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Name editing ──

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    await ref.read(profileProvider.notifier).updateFullName(name);
    if (!mounted) return;
    setState(() => _editingName = false);
    ToastService.showSuccess('Nombre actualizado');
  }
}

// ── Avatar Crop Editor ──

class _AvatarCropEditor extends StatefulWidget {
  final Uint8List imageBytes;

  const _AvatarCropEditor({required this.imageBytes});

  @override
  State<_AvatarCropEditor> createState() => _AvatarCropEditorState();
}

class _AvatarCropEditorState extends State<_AvatarCropEditor> {
  final TransformationController _transformController =
      TransformationController();
  final GlobalKey _viewerKey = GlobalKey();
  bool _processing = false;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final circleSize = screenWidth * 0.80;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.onSurface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.onSurface,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: const Text('Recortar foto'),
        leading: IconButton(
          icon: const Icon(Icons.close_outlined),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: ClipRect(
                child: SizedBox(
                  width: screenWidth,
                  height: screenWidth,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Zoomable/pannable image
                      RepaintBoundary(
                        key: _viewerKey,
                        child: InteractiveViewer(
                          transformationController: _transformController,
                          boundaryMargin: const EdgeInsets.all(200),
                          minScale: 0.5,
                          maxScale: 4.0,
                          child: Image.memory(
                            widget.imageBytes,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      // Circle mask overlay
                      IgnorePointer(
                        child: CustomPaint(
                          size: Size(screenWidth, screenWidth),
                          painter: _CircleMaskPainter(
                            circleSize: circleSize,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Confirm button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingLG),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _processing ? null : _cropAndReturn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    minimumSize:
                        const Size(0, AppConstants.minTouchHeight),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusLG),
                    ),
                  ),
                  child: _processing
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : const Text(
                          'Confirmar',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cropAndReturn() async {
    setState(() => _processing = true);

    try {
      final boundary = _viewerKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        Navigator.pop(context);
        return;
      }

      // Capture the viewer area at 512x512
      final image = await boundary.toImage(pixelRatio: 512.0 / boundary.size.width);
      final screenWidth = boundary.size.width;
      final circleSize = screenWidth * 0.80;
      final offset = (screenWidth - circleSize) / 2.0;
      final ratio = 512.0 / boundary.size.width;

      // Crop to circle area
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final srcRect = Rect.fromLTWH(
        offset * ratio,
        offset * ratio,
        circleSize * ratio,
        circleSize * ratio,
      );
      const dstRect = Rect.fromLTWH(0, 0, 512, 512);

      // Clip to circle
      canvas.clipPath(
        Path()..addOval(dstRect),
      );
      canvas.drawImageRect(image, srcRect, dstRect, Paint());

      final croppedImage = await recorder.endRecording().toImage(512, 512);
      final byteData =
          await croppedImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null && mounted) {
        Navigator.pop(context, byteData.buffer.asUint8List());
      } else if (mounted) {
        Navigator.pop(context);
      }
    } catch (e, stack) {
      if (mounted) {
        setState(() => _processing = false);
        ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
      }
    }
  }
}

// ── Circle Mask Painter ──

class _CircleMaskPainter extends CustomPainter {
  final double circleSize;

  _CircleMaskPainter({required this.circleSize});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = circleSize / 2;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // saveLayer required for BlendMode.clear to punch through
    canvas.saveLayer(rect, Paint());

    // Fill entire area with semi-transparent black
    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.6);
    canvas.drawRect(rect, bgPaint);

    // Punch transparent circle hole
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    canvas.drawCircle(center, radius, clearPaint);

    canvas.restore();

    // Draw thin white circle border
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _CircleMaskPainter oldDelegate) =>
      circleSize != oldDelegate.circleSize;
}
