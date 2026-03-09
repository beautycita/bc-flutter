import 'package:mocktail/mocktail.dart';
import 'package:beautycita/services/biometric_service.dart';
import 'package:beautycita/services/user_session.dart';
import 'package:beautycita/services/curate_service.dart';
import 'package:beautycita/services/follow_up_service.dart';
import 'package:beautycita/services/user_preferences.dart';
import 'package:beautycita/repositories/booking_repository.dart';
import 'package:beautycita/repositories/favorites_repository.dart';

class MockBiometricService extends Mock implements BiometricService {}

class MockUserSession extends Mock implements UserSession {}

class MockBookingRepository extends Mock implements BookingRepository {}

class MockFavoritesRepository extends Mock implements FavoritesRepository {}

class MockCurateService extends Mock implements CurateService {}

class MockFollowUpService extends Mock implements FollowUpService {}

class MockUserPreferences extends Mock implements UserPreferences {}
