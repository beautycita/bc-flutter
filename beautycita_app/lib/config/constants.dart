class AppConstants {
  // App Identity
  static const String appName = 'BeautyCita';
  static const String tagline = 'Tu agente de belleza inteligente';
  static const String version = '1.1.7';
  static const String tableErrorReports = 'user_error_reports';

  // Animation Durations
  static const Duration splashDuration = Duration(seconds: 2);
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
  static const Duration pageTransition = Duration(milliseconds: 350);
  static const Duration bottomSheetAnimation = Duration(milliseconds: 400);
  static const Duration shimmerAnimation = Duration(milliseconds: 1500);

  // Spacing & Layout (Thumb-zone friendly - bottom 60% focus)
  static const double thumbZoneStart = 0.4; // Top 40% is "stretch zone"
  static const double thumbZoneHeight = 0.6; // Bottom 60% is "comfort zone"

  static const double paddingXS = 4.0;
  static const double paddingSM = 8.0;
  static const double paddingMD = 16.0;
  static const double paddingLG = 24.0;
  static const double paddingXL = 32.0;
  static const double paddingXXL = 48.0;

  // Screen horizontal margins
  static const double screenPaddingHorizontal = 20.0;
  static const double screenPaddingVertical = 16.0;

  // Grid & Card Spacing
  static const double gridSpacing = 12.0;
  static const double cardSpacing = 16.0;
  static const int gridCrossAxisCount = 2;
  static const double gridChildAspectRatio = 0.85;

  // Touch Targets (minimum for comfortable thumb use)
  static const double minTouchHeight = 56.0;
  static const double comfortableTouchHeight = 64.0;
  static const double largeTouchHeight = 72.0;
  static const double iconTouchTarget = 48.0;

  // Border Radius
  static const double radiusXS = 8.0;
  static const double radiusSM = 12.0;
  static const double radiusMD = 16.0;
  static const double radiusLG = 24.0;
  static const double radiusXL = 32.0;
  static const double radiusFull = 999.0;

  // Elevation
  static const double elevationNone = 0.0;
  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;
  static const double elevationXHigh = 16.0;

  // Icon Sizes
  static const double iconSizeSM = 20.0;
  static const double iconSizeMD = 24.0;
  static const double iconSizeLG = 32.0;
  static const double iconSizeXL = 48.0;
  static const double iconSizeXXL = 64.0;

  // Avatar/Image Sizes
  static const double avatarSizeSM = 32.0;
  static const double avatarSizeMD = 48.0;
  static const double avatarSizeLG = 64.0;
  static const double avatarSizeXL = 96.0;

  // Category Card Sizes (for home grid)
  static const double categoryCardHeight = 140.0;
  static const double categoryIconSize = 56.0;

  // Bottom Sheet
  static const double bottomSheetMaxHeight = 0.85; // 85% of screen height
  static const double bottomSheetDragHandleWidth = 40.0;
  static const double bottomSheetDragHandleHeight = 4.0;
  static const double bottomSheetDragHandleRadius = 2.0;

  // Opacity
  static const double opacityDisabled = 0.38;
  static const double opacityMedium = 0.6;
  static const double opacityLight = 0.87;

  // Debounce/Throttle
  static const Duration searchDebounce = Duration(milliseconds: 500);
  static const Duration tapDebounce = Duration(milliseconds: 300);

  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration authTimeout = Duration(seconds: 15);

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Image Quality
  static const int imageQualityLow = 50;
  static const int imageQualityMedium = 75;
  static const int imageQualityHigh = 90;

  // Biometric Auth
  static const String biometricStorageKey = 'beautycita_biometric_token';
  static const String biometricReasonES = 'Accede a BeautyCita con tu huella o rostro';
  static const String biometricReasonEN = 'Access BeautyCita with your fingerprint or face';

  // Supabase Tables (for reference)
  static const String tableUsers = 'users';
  static const String tableServices = 'services';
  static const String tableBookings = 'bookings';
  static const String tableProviders = 'providers';
  static const String tableCategories = 'categories';

  // Storage Buckets
  static const String bucketAvatars = 'avatars';
  static const String bucketServiceImages = 'service_images';
  static const String bucketProviderImages = 'provider_images';

  // Cache Keys
  static const String cacheKeyCategories = 'cache_categories';
  static const String cacheKeyUserProfile = 'cache_user_profile';
  static const String cacheKeyRecentBookings = 'cache_recent_bookings';

  // Cache Duration
  static const Duration cacheDurationShort = Duration(minutes: 5);
  static const Duration cacheDurationMedium = Duration(hours: 1);
  static const Duration cacheDurationLong = Duration(days: 1);

  // URLs
  static const String privacyPolicyUrl = 'https://beautycita.com/privacy';
  static const String termsOfServiceUrl = 'https://beautycita.com/terms';
  static const String supportEmail = 'soporte@beautycita.com';

  // Regex Patterns
  static final RegExp emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  static final RegExp phoneRegex = RegExp(
    r'^[0-9]{10}$', // Mexican phone number format
  );

  // Error Messages (Spanish)
  static const String errorGeneric = 'Algo salió mal. Intenta de nuevo.';
  static const String errorNetwork = 'Sin conexión a internet.';
  static const String errorAuth = 'Error de autenticación.';
  static const String errorNotFound = 'No encontrado.';
  static const String errorPermissionDenied = 'Permiso denegado.';
  static const String errorBiometricNotAvailable = 'Autenticación biométrica no disponible.';
  static const String errorBiometricNotEnrolled = 'No tienes huellas o rostro registrado en tu dispositivo.';

  // Success Messages (Spanish)
  static const String successBookingCreated = '¡Cita reservada con éxito!';
  static const String successBookingCancelled = 'Cita cancelada.';
  static const String successProfileUpdated = 'Perfil actualizado.';

  // Feature Flags
  static const bool enableBiometricAuth = true;
  static const bool enableAnalytics = true;
  static const bool enableCrashReporting = true;
  static const bool enableDebugMode = false;

  // Private constructor to prevent instantiation
  AppConstants._();
}
