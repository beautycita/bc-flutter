import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita/models/follow_up_question.dart';
import '../helpers/model_fixtures.dart';

void main() {
  group('FollowUpQuestion', () {
    test('fromJson parses all fields', () {
      final json = followUpQuestionJson();
      final q = FollowUpQuestion.fromJson(json);

      expect(q.id, 'fq-1');
      expect(q.serviceType, 'manicure_gel');
      expect(q.questionOrder, 1);
      expect(q.questionKey, 'nail_shape');
      expect(q.questionTextEs, 'Que forma de uña prefieres?');
      expect(q.answerType, 'visual_cards');
      expect(q.isRequired, isTrue);
    });

    test('fromJson parses options list', () {
      final q = FollowUpQuestion.fromJson(followUpQuestionJson());

      expect(q.options, isNotNull);
      expect(q.options, hasLength(2));
      expect(q.options![0].labelEs, 'Almendra');
      expect(q.options![0].value, 'almond');
      expect(q.options![1].labelEs, 'Cuadrada');
      expect(q.options![1].value, 'square');
    });

    test('fromJson handles null options', () {
      final json = followUpQuestionJson();
      json['options'] = null;
      final q = FollowUpQuestion.fromJson(json);

      expect(q.options, isNull);
    });

    test('fromJson handles different answer types', () {
      for (final type in ['visual_cards', 'date_picker', 'yes_no']) {
        final q = FollowUpQuestion.fromJson(followUpQuestionJson(answerType: type));
        expect(q.answerType, type);
      }
    });
  });

  group('FollowUpOption', () {
    test('fromJson parses all fields', () {
      final json = {
        'label_es': 'Almendra',
        'label_en': 'Almond',
        'value': 'almond',
        'image_url': 'https://example.com/almond.jpg',
      };
      final option = FollowUpOption.fromJson(json);

      expect(option.labelEs, 'Almendra');
      expect(option.labelEn, 'Almond');
      expect(option.value, 'almond');
      expect(option.imageUrl, 'https://example.com/almond.jpg');
    });

    test('fromJson handles null imageUrl', () {
      final json = {
        'label_es': 'Cuadrada',
        'label_en': 'Square',
        'value': 'square',
        'image_url': null,
      };
      final option = FollowUpOption.fromJson(json);

      expect(option.imageUrl, isNull);
    });
  });
}
