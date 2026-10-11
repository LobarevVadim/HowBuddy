enum LessonExerciseType { singleChoice, multipleSelect, shortAnswer }

class LessonContent {
  const LessonContent({required this.content, required this.exercises});

  final String content;
  final List<LessonExercise> exercises;
}

class LessonExercise {
  const LessonExercise({
    required this.prompt,
    required this.type,
    required this.options,
    required this.correctAnswers,
    required this.explanation,
  });

  final String prompt;
  final LessonExerciseType type;
  final List<String> options;
  final Set<String> correctAnswers;
  final String explanation;

  factory LessonExercise.fromJson(Map<String, dynamic> json) {
    return LessonExercise(
      prompt: json['prompt'].toString(),
      type: LessonExerciseType.values.byName(json['type'].toString()),
      options: (json['options'] as List<dynamic>? ?? [])
          .map((option) => option.toString())
          .toList(),
      correctAnswers: (json['correctAnswers'] as List<dynamic>? ?? [])
          .map((answer) => answer.toString())
          .toSet(),
      explanation: json['explanation'].toString(),
    );
  }
}
