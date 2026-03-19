import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:beautycita/models/curate_result.dart';
import 'package:beautycita/providers/invite_provider.dart';
import 'package:beautycita/screens/invite_salon_screen.dart'
    show DiscoveredSalon;
import 'package:beautycita/services/invite_service.dart';
import 'package:beautycita/services/location_service.dart';

// ---------------------------------------------------------------------------
// Mocks & Fakes
// ---------------------------------------------------------------------------

class MockInviteService extends Mock implements InviteService {}

class FakeDiscoveredSalon extends Fake implements DiscoveredSalon {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _testLocation = LatLng(lat: 20.65, lng: -105.25);

DiscoveredSalon _salon({
  String id = 'salon-1',
  String name = 'Salón Bonito',
  String? phone = '+521234567890',
}) {
  return DiscoveredSalon(
    id: id,
    name: name,
    phone: phone,
    whatsapp: phone,
    address: 'Calle 1',
    city: 'Puerto Vallarta',
    rating: 4.5,
    reviewsCount: 100,
    interestCount: 5,
    distanceKm: 2.3,
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a [ProviderContainer] with the mock service injected.
ProviderContainer _createContainer(MockInviteService mockService) {
  return ProviderContainer(
    overrides: [
      inviteServiceProvider.overrideWithValue(mockService),
    ],
  );
}

/// Collects state transitions from the invite provider.
List<InviteState> _listenStates(ProviderContainer container) {
  final states = <InviteState>[];
  container.listen<InviteState>(
    inviteProvider,
    (prev, next) => states.add(next),
    fireImmediately: true,
  );
  return states;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(FakeDiscoveredSalon());
  });

  late MockInviteService mockService;

  setUp(() {
    mockService = MockInviteService();
    // Stub LocationService to return test location
    LocationService.testOverride = _testLocation;
  });

  tearDown(() {
    LocationService.testOverride = null;
  });

  group('InviteState', () {
    test('default state has loading step and empty salons', () {
      const state = InviteState();
      expect(state.step, InviteStep.loading);
      expect(state.salons, isEmpty);
      expect(state.selectedSalon, isNull);
      expect(state.suggestScrape, isFalse);
    });

    test('copyWith preserves values not overridden', () {
      final salon = _salon();
      final state = InviteState(
        step: InviteStep.browsing,
        salons: [salon],
        selectedSalon: salon,
        generatedBio: 'A great salon',
        inviteMessage: 'Hello!',
        serviceFilter: 'cabello',
        searchQuery: 'bonito',
        suggestScrape: true,
        userLocation: _testLocation,
        error: null,
        waUrl: 'https://wa.me/123',
      );

      final updated = state.copyWith(step: InviteStep.sent);
      expect(updated.step, InviteStep.sent);
      expect(updated.salons, hasLength(1));
      expect(updated.selectedSalon, salon);
      expect(updated.generatedBio, 'A great salon');
      expect(updated.waUrl, 'https://wa.me/123');
    });

    test('copyWith clear flags work', () {
      final salon = _salon();
      final state = InviteState(
        selectedSalon: salon,
        generatedBio: 'bio',
        inviteMessage: 'msg',
        searchQuery: 'query',
        waUrl: 'url',
      );

      final cleared = state.copyWith(
        clearSelectedSalon: true,
        clearBio: true,
        clearMessage: true,
        clearSearchQuery: true,
        clearWaUrl: true,
      );

      expect(cleared.selectedSalon, isNull);
      expect(cleared.generatedBio, isNull);
      expect(cleared.inviteMessage, isNull);
      expect(cleared.searchQuery, isNull);
      expect(cleared.waUrl, isNull);
    });
  });

  group('initialize()', () {
    test('fetches nearby salons and transitions loading → browsing', () async {
      final salons = [_salon(), _salon(id: 'salon-2', name: 'Corte Loco')];

      when(() => mockService.fetchNearbySalons(
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            serviceType: any(named: 'serviceType'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => salons);

      final container = _createContainer(mockService);
      final states = _listenStates(container);

      final notifier = container.read(inviteProvider.notifier);
      await notifier.initialize();

      // Should have gone through loading → browsing
      expect(states.any((s) => s.step == InviteStep.loading), isTrue);
      expect(states.last.step, InviteStep.browsing);
      expect(states.last.salons, hasLength(2));
      expect(states.last.userLocation, _testLocation);
    });

    test('passes serviceType filter to fetchNearbySalons', () async {
      when(() => mockService.fetchNearbySalons(
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            serviceType: 'cabello',
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [_salon()]);

      final container = _createContainer(mockService);
      final notifier = container.read(inviteProvider.notifier);
      await notifier.initialize(serviceType: 'cabello');

      verify(() => mockService.fetchNearbySalons(
            lat: _testLocation.lat,
            lng: _testLocation.lng,
            serviceType: 'cabello',
            limit: 20,
          )).called(1);

      expect(container.read(inviteProvider).serviceFilter, 'cabello');
    });

    test('sets error when location unavailable', () async {
      LocationService.testOverride = null;
      // Override to return null
      LocationService.testOverrideNull = true;

      final container = _createContainer(mockService);
      final notifier = container.read(inviteProvider.notifier);
      await notifier.initialize();

      expect(container.read(inviteProvider).step, InviteStep.error);
      expect(container.read(inviteProvider).error, contains('ubicación'));

      LocationService.testOverrideNull = false;
    });

    test('sets error when fetchNearbySalons throws', () async {
      when(() => mockService.fetchNearbySalons(
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            serviceType: any(named: 'serviceType'),
            limit: any(named: 'limit'),
          )).thenThrow(InviteException('Network error', statusCode: 500));

      final container = _createContainer(mockService);
      final notifier = container.read(inviteProvider.notifier);
      await notifier.initialize();

      expect(container.read(inviteProvider).step, InviteStep.error);
      expect(container.read(inviteProvider).error, contains('Network error'));
    });
  });

  group('searchSalons()', () {
    test('transitions searching → browsing with results', () async {
      final salons = [_salon()];

      when(() => mockService.fetchNearbySalons(
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            serviceType: any(named: 'serviceType'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => salons);

      when(() => mockService.searchSalons(
            query: 'barberia',
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
          )).thenAnswer(
              (_) async => (salons: [_salon(name: 'Barbería')], suggestScrape: false));

      final container = _createContainer(mockService);
      final notifier = container.read(inviteProvider.notifier);
      await notifier.initialize();

      final states = _listenStates(container);
      await notifier.searchSalons('barberia');

      expect(states.any((s) => s.step == InviteStep.searching), isTrue);
      expect(states.last.step, InviteStep.browsing);
      expect(states.last.salons.first.name, 'Barbería');
      expect(states.last.suggestScrape, isFalse);
    });

    test('sets suggestScrape when search returns empty', () async {
      when(() => mockService.fetchNearbySalons(
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            serviceType: any(named: 'serviceType'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [_salon()]);

      when(() => mockService.searchSalons(
            query: 'unknown',
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
          )).thenAnswer((_) async => (salons: <DiscoveredSalon>[], suggestScrape: true));

      final container = _createContainer(mockService);
      final notifier = container.read(inviteProvider.notifier);
      await notifier.initialize();
      await notifier.searchSalons('unknown');

      final state = container.read(inviteProvider);
      expect(state.step, InviteStep.browsing);
      expect(state.salons, isEmpty);
      expect(state.suggestScrape, isTrue);
    });

    test('search error transitions to error step', () async {
      when(() => mockService.fetchNearbySalons(
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            serviceType: any(named: 'serviceType'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [_salon()]);

      when(() => mockService.searchSalons(
            query: any(named: 'query'),
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
          )).thenThrow(InviteException('Search failed'));

      final container = _createContainer(mockService);
      final notifier = container.read(inviteProvider.notifier);
      await notifier.initialize();
      await notifier.searchSalons('boom');

      expect(container.read(inviteProvider).step, InviteStep.error);
    });
  });

  group('scrapeAndShow()', () {
    test('transitions scraping → salonDetail with salon added to list',
        () async {
      final existingSalon = _salon();
      final scrapedSalon = _salon(id: 'scraped-1', name: 'Nuevo Salón');

      when(() => mockService.fetchNearbySalons(
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            serviceType: any(named: 'serviceType'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [existingSalon]);

      when(() => mockService.scrapeAndEnrich(
            query: 'nuevo',
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
          )).thenAnswer((_) async => scrapedSalon);

      when(() => mockService.generateBio(scrapedSalon))
          .thenAnswer((_) async => 'Great new salon');

      final container = _createContainer(mockService);
      final notifier = container.read(inviteProvider.notifier);
      await notifier.initialize();

      final states = _listenStates(container);
      await notifier.scrapeAndShow('nuevo');

      expect(states.any((s) => s.step == InviteStep.scraping), isTrue);
      expect(states.last.step, InviteStep.salonDetail);
      expect(states.last.selectedSalon?.id, 'scraped-1');
      // Scraped salon should be prepended to the list
      expect(states.last.salons.first.id, 'scraped-1');
      expect(states.last.salons, hasLength(2));
    });

    test('sets error when scrape returns null', () async {
      when(() => mockService.fetchNearbySalons(
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            serviceType: any(named: 'serviceType'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => []);

      when(() => mockService.scrapeAndEnrich(
            query: any(named: 'query'),
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
          )).thenAnswer((_) async => null);

      final container = _createContainer(mockService);
      final notifier = container.read(inviteProvider.notifier);
      await notifier.initialize();
      await notifier.scrapeAndShow('ghost');

      expect(container.read(inviteProvider).step, InviteStep.error);
      expect(container.read(inviteProvider).error, contains('No encontramos'));
    });
  });

  group('selectSalon()', () {
    test('transitions to salonDetail and loads bio', () async {
      final salon = _salon();

      when(() => mockService.fetchNearbySalons(
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            serviceType: any(named: 'serviceType'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [salon]);

      when(() => mockService.generateBio(salon))
          .thenAnswer((_) async => 'Beautiful salon in PV');

      final container = _createContainer(mockService);
      final notifier = container.read(inviteProvider.notifier);
      await notifier.initialize();
      await notifier.selectSalon(salon);

      final state = container.read(inviteProvider);
      expect(state.step, InviteStep.salonDetail);
      expect(state.selectedSalon, salon);
      expect(state.generatedBio, 'Beautiful salon in PV');
    });

    test('clears previous message and waUrl on new selection', () async {
      final salon1 = _salon();
      final salon2 = _salon(id: 'salon-2', name: 'Otro Salón');

      when(() => mockService.fetchNearbySalons(
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            serviceType: any(named: 'serviceType'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [salon1, salon2]);

      when(() => mockService.generateBio(any()))
          .thenAnswer((_) async => 'bio');

      when(() => mockService.generateInviteMessage(
            userName: any(named: 'userName'),
            salon: salon1,
            serviceSearched: any(named: 'serviceSearched'),
          )).thenAnswer((_) async => 'invite msg');

      final container = _createContainer(mockService);
      final notifier = container.read(inviteProvider.notifier);
      await notifier.initialize();
      await notifier.selectSalon(salon1);
      await notifier.generateMessage();

      // Now select a different salon
      await notifier.selectSalon(salon2);
      final state = container.read(inviteProvider);
      expect(state.selectedSalon?.id, 'salon-2');
      expect(state.inviteMessage, isNull);
      expect(state.waUrl, isNull);
    });
  });

  group('generateMessage()', () {
    test('transitions generating → readyToSend', () async {
      final salon = _salon();

      when(() => mockService.fetchNearbySalons(
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            serviceType: any(named: 'serviceType'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [salon]);

      when(() => mockService.generateBio(salon))
          .thenAnswer((_) async => 'bio');

      when(() => mockService.generateInviteMessage(
            userName: any(named: 'userName'),
            salon: salon,
            serviceSearched: any(named: 'serviceSearched'),
          )).thenAnswer((_) async => 'Hola, te invitamos a BeautyCita!');

      final container = _createContainer(mockService);
      final notifier = container.read(inviteProvider.notifier);
      await notifier.initialize();
      await notifier.selectSalon(salon);

      final states = _listenStates(container);
      await notifier.generateMessage();

      expect(states.any((s) => s.step == InviteStep.generating), isTrue);
      expect(states.last.step, InviteStep.readyToSend);
      expect(states.last.inviteMessage, 'Hola, te invitamos a BeautyCita!');
    });

    test('regenerate replaces previous message', () async {
      final salon = _salon();
      var callCount = 0;

      when(() => mockService.fetchNearbySalons(
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            serviceType: any(named: 'serviceType'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [salon]);

      when(() => mockService.generateBio(salon))
          .thenAnswer((_) async => 'bio');

      when(() => mockService.generateInviteMessage(
            userName: any(named: 'userName'),
            salon: salon,
            serviceSearched: any(named: 'serviceSearched'),
          )).thenAnswer((_) async {
        callCount++;
        return 'Message v$callCount';
      });

      final container = _createContainer(mockService);
      final notifier = container.read(inviteProvider.notifier);
      await notifier.initialize();
      await notifier.selectSalon(salon);

      await notifier.generateMessage();
      expect(container.read(inviteProvider).inviteMessage, 'Message v1');

      await notifier.generateMessage();
      expect(container.read(inviteProvider).inviteMessage, 'Message v2');
    });

    test('error during generation transitions to error step', () async {
      final salon = _salon();

      when(() => mockService.fetchNearbySalons(
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            serviceType: any(named: 'serviceType'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [salon]);

      when(() => mockService.generateBio(salon))
          .thenAnswer((_) async => 'bio');

      when(() => mockService.generateInviteMessage(
            userName: any(named: 'userName'),
            salon: salon,
            serviceSearched: any(named: 'serviceSearched'),
          )).thenThrow(InviteException('AI offline'));

      final container = _createContainer(mockService);
      final notifier = container.read(inviteProvider.notifier);
      await notifier.initialize();
      await notifier.selectSalon(salon);
      await notifier.generateMessage();

      expect(container.read(inviteProvider).step, InviteStep.error);
    });
  });

  group('sendInvite()', () {
    test('transitions sending → sent with waUrl set', () async {
      final salon = _salon();

      when(() => mockService.fetchNearbySalons(
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            serviceType: any(named: 'serviceType'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [salon]);

      when(() => mockService.generateBio(salon))
          .thenAnswer((_) async => 'bio');

      when(() => mockService.generateInviteMessage(
            userName: any(named: 'userName'),
            salon: salon,
            serviceSearched: any(named: 'serviceSearched'),
          )).thenAnswer((_) async => 'invite msg');

      when(() => mockService.sendInvite(
            salonId: salon.id,
            inviteMessage: 'invite msg',
          )).thenAnswer((_) async => 'https://wa.me/521234567890?text=invite+msg');

      final container = _createContainer(mockService);
      final notifier = container.read(inviteProvider.notifier);
      await notifier.initialize();
      await notifier.selectSalon(salon);
      await notifier.generateMessage();

      final states = _listenStates(container);
      await notifier.sendInvite();

      expect(states.any((s) => s.step == InviteStep.sending), isTrue);
      expect(states.last.step, InviteStep.sent);
      expect(states.last.waUrl, contains('wa.me'));
    });

    test('error when salon has no phone', () async {
      final salon = _salon(phone: null);

      when(() => mockService.fetchNearbySalons(
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            serviceType: any(named: 'serviceType'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [salon]);

      when(() => mockService.generateBio(salon))
          .thenAnswer((_) async => 'bio');

      when(() => mockService.generateInviteMessage(
            userName: any(named: 'userName'),
            salon: salon,
            serviceSearched: any(named: 'serviceSearched'),
          )).thenAnswer((_) async => 'invite msg');

      final container = _createContainer(mockService);
      final notifier = container.read(inviteProvider.notifier);
      await notifier.initialize();
      await notifier.selectSalon(salon);
      await notifier.generateMessage();
      await notifier.sendInvite();

      expect(container.read(inviteProvider).step, InviteStep.error);
      expect(container.read(inviteProvider).error, contains('teléfono'));
    });

    test('send error transitions to error step', () async {
      final salon = _salon();

      when(() => mockService.fetchNearbySalons(
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            serviceType: any(named: 'serviceType'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [salon]);

      when(() => mockService.generateBio(salon))
          .thenAnswer((_) async => 'bio');

      when(() => mockService.generateInviteMessage(
            userName: any(named: 'userName'),
            salon: salon,
            serviceSearched: any(named: 'serviceSearched'),
          )).thenAnswer((_) async => 'msg');

      when(() => mockService.sendInvite(
            salonId: any(named: 'salonId'),
            inviteMessage: any(named: 'inviteMessage'),
          )).thenThrow(InviteException('WA API down'));

      final container = _createContainer(mockService);
      final notifier = container.read(inviteProvider.notifier);
      await notifier.initialize();
      await notifier.selectSalon(salon);
      await notifier.generateMessage();
      await notifier.sendInvite();

      expect(container.read(inviteProvider).step, InviteStep.error);
    });
  });

  group('backToList() / clearSearch()', () {
    test('backToList returns to browsing and clears detail state', () async {
      final salon = _salon();

      when(() => mockService.fetchNearbySalons(
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            serviceType: any(named: 'serviceType'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [salon]);

      when(() => mockService.generateBio(salon))
          .thenAnswer((_) async => 'bio');

      final container = _createContainer(mockService);
      final notifier = container.read(inviteProvider.notifier);
      await notifier.initialize();
      await notifier.selectSalon(salon);

      notifier.backToList();
      final state = container.read(inviteProvider);
      expect(state.step, InviteStep.browsing);
      expect(state.selectedSalon, isNull);
      expect(state.generatedBio, isNull);
      expect(state.inviteMessage, isNull);
    });

    test('clearSearch re-initializes with original service filter', () async {
      when(() => mockService.fetchNearbySalons(
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            serviceType: 'uñas',
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [_salon()]);

      final container = _createContainer(mockService);
      final notifier = container.read(inviteProvider.notifier);
      await notifier.initialize(serviceType: 'uñas');

      notifier.clearSearch();

      // Should re-fetch with the same service filter
      await Future<void>.delayed(Duration.zero);
      verify(() => mockService.fetchNearbySalons(
            lat: _testLocation.lat,
            lng: _testLocation.lng,
            serviceType: 'uñas',
            limit: 20,
          )).called(greaterThanOrEqualTo(2));
    });
  });
}
