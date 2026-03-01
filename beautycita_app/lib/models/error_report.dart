class ErrorReport {
  final String? userId;
  final String errorMessage;
  final String? errorDetails;
  final String? screenName;
  final String? deviceInfo;
  final String? appVersion;

  const ErrorReport({
    this.userId,
    required this.errorMessage,
    this.errorDetails,
    this.screenName,
    this.deviceInfo,
    this.appVersion,
  });

  Map<String, dynamic> toInsertMap() => {
        'user_id': userId,
        'error_message': errorMessage,
        'error_details': errorDetails,
        'screen_name': screenName,
        'device_info': deviceInfo,
        'app_version': appVersion,
      };
}
