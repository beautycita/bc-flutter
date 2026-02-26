class FollowUpQuestion {
  final String id;
  final String serviceType;
  final int questionOrder;
  final String questionKey;
  final String questionTextEs;
  final String answerType; // 'visual_cards' | 'date_picker' | 'yes_no'
  final List<FollowUpOption>? options;
  final bool isRequired;

  const FollowUpQuestion({
    required this.id,
    required this.serviceType,
    required this.questionOrder,
    required this.questionKey,
    required this.questionTextEs,
    required this.answerType,
    this.options,
    required this.isRequired,
  });

  factory FollowUpQuestion.fromJson(Map<String, dynamic> json) {
    return FollowUpQuestion(
      id: json['id'] as String,
      serviceType: json['service_type'] as String,
      questionOrder: json['question_order'] as int,
      questionKey: json['question_key'] as String,
      questionTextEs: json['question_text_es'] as String,
      answerType: json['answer_type'] as String,
      options: json['options'] != null
          ? (json['options'] as List<dynamic>)
              .map((o) => FollowUpOption.fromJson(o as Map<String, dynamic>))
              .toList()
          : null,
      isRequired: json['is_required'] as bool,
    );
  }
}

class FollowUpOption {
  final String labelEs;
  final String labelEn;
  final String value;
  final String? imageUrl;

  const FollowUpOption({
    required this.labelEs,
    required this.labelEn,
    required this.value,
    this.imageUrl,
  });

  factory FollowUpOption.fromJson(Map<String, dynamic> json) {
    return FollowUpOption(
      labelEs: json['label_es'] as String,
      labelEn: json['label_en'] as String,
      value: json['value'] as String,
      imageUrl: json['image_url'] as String?,
    );
  }
}
