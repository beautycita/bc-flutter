import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('invite_service.generateBio sends discovered_salon_id + reads bio', () {
    final source =
        File('lib/services/invite_service.dart').readAsStringSync();

    expect(source.contains("'discovered_salon_id'"), isTrue,
        reason: "edge fn requires discovered_salon_id — must be in body");
    expect(source.contains("data['bio']"), isTrue,
        reason: "edge fn returns {bio}, not {text}");
    expect(source.contains("data['text']"), isFalse,
        reason: "stale text-key read must be removed");
  });

  test('contact_match_provider uses generate_salon_bio + canonical keys', () {
    final source =
        File('lib/providers/contact_match_provider.dart').readAsStringSync();

    expect(source.contains("'generate_salon_bio'"), isTrue,
        reason: "action must be generate_salon_bio");
    expect(source.contains("'generate_bio'"), isFalse,
        reason: "ghost action 'generate_bio' must be removed");
    expect(source.contains("'discovered_salon_id'"), isTrue,
        reason: "edge fn requires discovered_salon_id");
    expect(source.contains("'salon_specialties'"), isTrue,
        reason: "key is salon_specialties (not salon_categories)");
    expect(source.contains("'salon_review_count'"), isTrue,
        reason: "key is salon_review_count (not salon_reviews_count)");
  });
}
