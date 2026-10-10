class Account {
  const Account({
    required this.id,
    required this.fullName,
    required this.email,
  });

  final String id;
  final String fullName;
  final String email;

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'].toString(),
      fullName: json['fullName'].toString(),
      email: json['email'].toString(),
    );
  }
}

class LessonLevel {
  const LessonLevel({
    required this.id,
    required this.level,
    required this.shape,
    required this.title,
    required this.isCompleted,
    required this.isUnlocked,
  });

  final String id;
  final int level;
  final String shape;
  final String title;
  final bool isCompleted;
  final bool isUnlocked;

  factory LessonLevel.fromJson(Map<String, dynamic> json) {
    return LessonLevel(
      id: json['id'].toString(),
      level: int.parse(json['level'].toString()),
      shape: json['shape'].toString(),
      title: json['title'].toString(),
      isCompleted: json['isCompleted'] == true,
      isUnlocked: json['isUnlocked'] == true,
    );
  }
}

class LessonCompletion {
  const LessonCompletion({required this.topicCompleted});

  final bool topicCompleted;

  factory LessonCompletion.fromJson(Map<String, dynamic> json) {
    return LessonCompletion(topicCompleted: json['topicCompleted'] == true);
  }
}

class LessonTopic {
  const LessonTopic({
    required this.id,
    required this.question,
    required this.lessonCount,
  });

  final String id;
  final String question;
  final int lessonCount;

  factory LessonTopic.fromJson(Map<String, dynamic> json) {
    return LessonTopic(
      id: json['id'].toString(),
      question: json['question'].toString(),
      lessonCount: int.parse(json['lessonCount'].toString()),
    );
  }
}

class TreeData {
  const TreeData({
    required this.topic,
    required this.levels,
    required this.nextQuestions,
  });

  final LessonTopic topic;
  final List<LessonLevel> levels;
  final List<String> nextQuestions;
}

class NotepadTreeNode {
  const NotepadTreeNode({
    required this.id,
    required this.title,
    required this.children,
    required this.isCompleted,
  });

  final String id;
  final String title;
  final List<NotepadTreeNode> children;
  final bool isCompleted;

  factory NotepadTreeNode.fromJson(Map<String, dynamic> json) {
    final children = (json['children'] as List<dynamic>? ?? [])
        .map((child) => NotepadTreeNode.fromJson(child as Map<String, dynamic>))
        .toList();

    return NotepadTreeNode(
      id: json['id'].toString(),
      title: json['title'].toString(),
      children: children,
      isCompleted: json['isCompleted'] == true,
    );
  }
}

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
