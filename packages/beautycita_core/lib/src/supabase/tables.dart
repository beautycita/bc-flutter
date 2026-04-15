/// All Supabase table name constants.
///
/// Single source of truth — never hard-code table names elsewhere.
/// Tables are grouped by domain for readability.
abstract final class BCTables {
  // ── User / Auth ──────────────────────────────────────────────────────
  static const String profiles = 'profiles';
  static const String qrAuthSessions = 'qr_auth_sessions';
  static const String userTotpSecrets = 'user_totp_secrets';

  // ── Businesses & Staff ───────────────────────────────────────────────
  static const String businesses = 'businesses';
  static const String staff = 'staff';
  static const String staffServices = 'staff_services';
  static const String staffSchedules = 'staff_schedules';
  static const String staffScheduleBlocks = 'staff_schedule_blocks';
  static const String stylistApplications = 'stylist_applications';

  // ── Services & Categories ────────────────────────────────────────────
  static const String services = 'services';
  static const String serviceCategoriesTree = 'service_categories_tree';
  static const String serviceProfiles = 'service_profiles';
  static const String serviceFollowUpQuestions = 'service_follow_up_questions';

  // ── Bookings & Payments ──────────────────────────────────────────────
  static const String appointments = 'appointments';
  static const String bookings = 'bookings';
  static const String payments = 'payments';
  static const String disputes = 'disputes';
  static const String orders = 'orders';
  static const String giftCards = 'gift_cards';
  static const String loyaltyTransactions = 'loyalty_transactions';
  static const String stripeCustomerMapping = 'stripe_customer_mapping';
  static const String posAgreements = 'pos_agreements';

  // ── Intelligence Engine ──────────────────────────────────────────────
  static const String engineSettings = 'engine_settings';
  static const String timeInferenceRules = 'time_inference_rules';

  // ── Reviews & Favorites ──────────────────────────────────────────────
  static const String reviews = 'reviews';
  static const String favorites = 'favorites';

  // ── Chat / Aphrodite ─────────────────────────────────────────────────
  static const String chatThreads = 'chat_threads';
  static const String chatMessages = 'chat_messages';
  static const String aphroditeCopyLog = 'aphrodite_copy_log';

  // ── Media ────────────────────────────────────────────────────────────
  static const String userMedia = 'user_media';
  static const String avatars = 'avatars';
  static const String portfolioPhotos = 'portfolio_photos';

  // ── Outreach / Discovery ─────────────────────────────────────────────
  static const String discoveredSalons = 'discovered_salons';
  static const String salonOutreachLog = 'salon_outreach_log';
  static const String outreachTemplates = 'outreach_templates';

  // ── Business CRM ────────────────────────────────────────────────
  static const String businessClients = 'business_clients';
  static const String businessClosures = 'business_closures';
  static const String automatedMessages = 'automated_messages';
  static const String automatedMessageLog = 'automated_message_log';
  static const String staffCommissions = 'staff_commissions';

  // ── RP & Assignments ────────────────────────────────────────────
  static const String rpAssignments = 'rp_assignments';
  static const String rpChecklist = 'rp_checklist';
  static const String rpMeetings = 'rp_meetings';
  static const String rpVisits = 'rp_visits';

  // ── Transport ───────────────────────────────────────────────────
  static const String uberRides = 'uber_rides';

  // ── User Reports ────────────────────────────────────────────────
  static const String userErrorReports = 'user_error_reports';
  static const String contactSubmissions = 'contact_submissions';

  // ── Feed / Engagement ───────────────────────────────────────────
  static const String feedEngagement = 'feed_engagement';
  static const String feedSaves = 'feed_saves';

  // ── Behavioral Intelligence ─────────────────────────────────────
  static const String userBehaviorEvents = 'user_behavior_events';
  static const String userTraitScores = 'user_trait_scores';
  static const String userBehaviorSummaries = 'user_behavior_summaries';
  static const String behaviorTriggers = 'behavior_triggers';
  static const String behaviorTriggerLog = 'behavior_trigger_log';

  // ── Auth / WebAuthn ─────────────────────────────────────────────
  static const String webauthnCredentials = 'webauthn_credentials';

  // ── Notifications ────────────────────────────────────────────────────
  static const String notifications = 'notifications';
  static const String notificationTemplates = 'notification_templates';

  // ── Admin / Config ───────────────────────────────────────────────────
  static const String appConfig = 'app_config';
  static const String auditLog = 'audit_log';

  // ── POS / Marketplace ────────────────────────────────────────────
  static const String products = 'products';
  static const String productShowcases = 'product_showcases';

  // ── Tax & CFDI ────────────────────────────────────────────────────────
  static const String taxWithholdings = 'tax_withholdings';
  static const String satMonthlyReports = 'sat_monthly_reports';
  static const String businessExpenses = 'business_expenses';
  static const String cfdiRecords = 'cfdi_records';

  static const String salonDebts = 'salon_debts';
  static const String debtPayments = 'debt_payments';
  static const String platformSatDeclarations = 'platform_sat_declarations';

  // ── Payouts & Commissions ─────────────────────────────────────────────
  static const String payoutRecords = 'payout_records';
  static const String commissionRecords = 'commission_records';
}
