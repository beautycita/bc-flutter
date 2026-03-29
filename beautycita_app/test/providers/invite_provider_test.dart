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

/// Stubs generateBio to return a value (called in background by _loadBio).
void _stubGenerateBio(MockInviteService mockService, {String bio = 'bio'}) {
  when(() => mockService.generateBio(any()))
      .thenAnswer((_) async => bio);
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
    // Default: stub generateBio so _loadBio's fire-and-forget doesn't crash
    _stubGenerateBio(mockService);
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

      final container = _createContainer(mockService);
      final notifier = container.read(inviteProvider.notifier);
      await notifier.initialize();

      final states = _listenStates(container);
      await notifier.scrapeAndShow('nuevo');

      // scrapeAndShow also calls _loadBio which calls selectSalon-like flow
      // ending in readyToSend (auto-generateMessage) or salonDetail
      expect(states.any((s) => s.step == InviteStep.scraping), isTrue);
      // After scrape + bio + auto-generate, should be at readyToSend
      final finalState = states.last;
      expect(finalState.selectedSalon?.id, 'scraped-1');
      // Scraped salon should be prepended to the list
      expect(finalState.salons.first.id, 'scraped-1');
      expect(finalState.salons, hasLength(2));
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
    test('transitions to readyToSend with bio and auto-generated message',
        () async {
      final salon = _salon();

      when(() => mockService.fetchNearbySalons(
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            serviceType: any(named: 'serviceType'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [salon]);

      final container = _createContainer(mockService);
      // Keep provider alive (autoDispose)
      final states = _listenStates(container);

      final notifier = container.read(inviteProvider.notifier);
      await notifier.initialize();
      await notifier.selectSalon(salon);

      // Let fire-and-forget bio complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(inviteProvider);
      // selectSalon now auto-calls generateMessage, ending at readyToSend
      expect(state.step, InviteStep.readyToSend);
      expect(state.selectedSalon, salon);
      // Bio is generated locally (fallback) then enriched in background
      expect(state.generatedBio, isNotNull);
      // Message is auto-generated from local templates
      expect(state.inviteMessage, isNotNull);
      expect(state.inviteMessage, contains('BeautyCita'));
      // Verify we went through expected steps
      expect(states.any((s) => s.step == InviteStep.salonDetail), isTrue);
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

      final container = _createContainer(mockService);
      // Keep provider alive (autoDispose)
      _listenStates(container);

      final notifier = container.read(inviteProvider.notifier);
      await notifier.initialize();
      await notifier.selectSalon(salon1);

      // Now select a different salon — previous message/waUrl should be cleared
      // and new message auto-generated
      await notifier.selectSalon(salon2);

      // Let fire-and-forget bio complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(inviteProvider);
      expect(state.selectedSalon?.id, 'salon-2');
      // New message was auto-generated (not null — cleared then regenerated)
      expect(state.inviteMessage, isNotNull);
      expect(state.inviteMessage, contains('BeautyCita'));
      expect(state.waUrl, isNull); // waUrl starts null on new selection
    });
  });

  group('generateMessage()', () {
    test('produces a message from local templates at readyToSend', () async {
      final salon = _salon();

      when(() => mockService.fetchNearbySalons(
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            serviceType: any(named: 'serviceType'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [salon]);

      final container = _createContainer(mockService);
      final notifier = container.read(inviteProvider.notifier);
      await notifier.initialize();
      // selectSalon auto-calls generateMessage
      await notifier.selectSalon(salon);

      final state = container.read(inviteProvider);
      expect(state.step, InviteStep.readyToSend);
      expect(state.inviteMessage, isNotNull);
      expect(state.inviteMessage, contains('BeautyCita'));
    });

    test('regenerate produces a different message', () async {
      final salon = _salon();

      when(() => mockService.fetchNearbySalons(
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            serviceType: any(named: 'serviceType'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [salon]);

      final container = _createContainer(mockService);
      final notifier = container.read(inviteProvider.notifier);
      await notifier.initialize();
      await notifier.selectSalon(salon);

      final firstMessage = container.read(inviteProvider).inviteMessage;
      expect(firstMessage, isNotNull);

      // Regenerate should cycle to a different template
      await notifier.generateMessage();
      final secondMessage = container.read(inviteProvider).inviteMessage;
      expect(secondMessage, isNotNull);
      expect(secondMessage, contains('BeautyCita'));
      // Templates cycle, so the new message should be different
      expect(secondMessage, isNot(equals(firstMessage)));
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

      when(() => mockService.sendInvite(
            salonId: any(named: 'salonId'),
            inviteMessage: any(named: 'inviteMessage'),
          )).thenAnswer((_) async => 'https://wa.me/521234567890?text=invite+msg');

      final container = _createContainer(mockService);
      final notifier = container.read(inviteProvider.notifier);
      await notifier.initialize();
      await notifier.selectSalon(salon);

      // selectSalon auto-generates message, now we're at readyToSend
      expect(container.read(inviteProvider).step, InviteStep.readyToSend);

      final states = _listenStates(container);
      await notifier.sendInvite();

      expect(states.any((s) => s.step == InviteStep.sending), isTrue);
      expect(states.last.step, InviteStep.sent);
      expect(states.last.waUrl, contains('wa.me'));
    });

    test('error when sendInvite service throws', () async {
      final salon = _salon();

      when(() => mockService.fetchNearbySalons(
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            serviceType: any(named: 'serviceType'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [salon]);

      when(() => mockService.sendInvite(
            salonId: any(named: 'salonId'),
            inviteMessage: any(named: 'inviteMessage'),
          )).thenThrow(InviteException('WA API down'));

      final container = _createContainer(mockService);
      final notifier = container.read(inviteProvider.notifier);
      await notifier.initialize();
      await notifier.selectSalon(salon);
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
