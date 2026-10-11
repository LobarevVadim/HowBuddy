enum LessonExerciseType {
  singleChoice,
  multipleSelect,
  shortAnswer,
  orderSteps,
  matching,
}

class ExercisePair {
  const ExercisePair({required this.left, required this.right});

  final String left;
  final String right;

  factory ExercisePair.fromJson(Map<String, dynamic> json) {
    return ExercisePair(
      left: json['left'].toString(),
      right: json['right'].toString(),
    );
  }
}

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
    required this.correctOrder,
    required this.pairs,
    required this.explanation,
  });

  final String prompt;
  final LessonExerciseType type;
  final List<String> options;
  final Set<String> correctAnswers;
  final List<String> correctOrder;
  final List<ExercisePair> pairs;
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
      correctOrder: (json['correctOrder'] as List<dynamic>? ?? [])
          .map((answer) => answer.toString())
          .toList(),
      pairs: (json['pairs'] as List<dynamic>? ?? [])
          .map((pair) => ExercisePair.fromJson(pair as Map<String, dynamic>))
          .toList(),
      explanation: json['explanation'].toString(),
    );
  }
}
