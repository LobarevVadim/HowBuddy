class Account {
  const Account({
    required this.id,
    required this.fullName,
    required this.email,
    this.avatarPaletteIndex = 0,
    this.glassesAccessoryIndex = 0,
    this.preferredLanguage,
    this.ageYears,
  });

  final String id;
  final String fullName;
  final String email;
  final int avatarPaletteIndex;
  final int glassesAccessoryIndex;
  final String? preferredLanguage;
  final int? ageYears;

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'].toString(),
      fullName: json['fullName'].toString(),
      email: json['email'].toString(),
      avatarPaletteIndex:
          int.tryParse(json['avatarPaletteIndex']?.toString() ?? '') ?? 0,
      glassesAccessoryIndex:
          int.tryParse(json['glassesAccessoryIndex']?.toString() ?? '') ?? 0,
      preferredLanguage: json['preferredLanguage']?.toString(),
      ageYears: int.tryParse(json['ageYears']?.toString() ?? ''),
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
  const LessonCompletion({
    required this.topicCompleted,
    required this.earnedXp,
    required this.totalXp,
  });

  final bool topicCompleted;
  final int earnedXp;
  final int totalXp;

  factory LessonCompletion.fromJson(Map<String, dynamic> json) {
    return LessonCompletion(
      topicCompleted: json['topicCompleted'] == true,
      earnedXp: int.tryParse(json['earnedXp'].toString()) ?? 0,
      totalXp: int.tryParse(json['totalXp'].toString()) ?? 0,
    );
  }
}

class XpDay {
  const XpDay({required this.date, required this.xp});

  final DateTime date;
  final int xp;

  factory XpDay.fromJson(Map<String, dynamic> json) {
    return XpDay(
      date: DateTime.parse(json['date'].toString()),
      xp: int.tryParse(json['xp'].toString()) ?? 0,
    );
  }
}

class XpWeeklySummary {
  const XpWeeklySummary({
    required this.totalXp,
    required this.days,
    required this.leaderboard,
    required this.yourPlace,
  });

  final int totalXp;
  final List<XpDay> days;
  final List<LeaderboardEntry> leaderboard;
  final LeaderboardEntry? yourPlace;

  factory XpWeeklySummary.fromJson(Map<String, dynamic> json) {
    return XpWeeklySummary(
      totalXp: int.tryParse(json['totalXp'].toString()) ?? 0,
      days: (json['days'] as List<dynamic>? ?? [])
          .map((day) => XpDay.fromJson(day as Map<String, dynamic>))
          .toList(),
      leaderboard: (json['leaderboard'] as List<dynamic>? ?? [])
          .map(
            (entry) => LeaderboardEntry.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
      yourPlace: json['yourPlace'] is Map<String, dynamic>
          ? LeaderboardEntry.fromJson(json['yourPlace'] as Map<String, dynamic>)
          : null,
    );
  }
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.name,
    required this.xp,
    required this.place,
    required this.isYou,
    this.avatarPaletteIndex = 0,
    this.glassesAccessoryIndex = 0,
  });

  final String name;
  final int xp;
  final int place;
  final bool isYou;
  final int avatarPaletteIndex;
  final int glassesAccessoryIndex;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      name: json['name'].toString(),
      xp: int.tryParse(json['xp'].toString()) ?? 0,
      place: int.tryParse(json['place'].toString()) ?? 0,
      isYou: json['isYou'] == true,
      avatarPaletteIndex:
          int.tryParse(json['avatarPaletteIndex']?.toString() ?? '') ?? 0,
      glassesAccessoryIndex:
          int.tryParse(json['glassesAccessoryIndex']?.toString() ?? '') ?? 0,
    );
  }
}

class GameState {
  const GameState({
    required this.hearts,
    required this.heartRechargeAt,
    required this.emeralds,
    required this.streakCount,
    required this.studyDays,
    required this.xpBoostUntil,
  });

  final int hearts;
  final DateTime? heartRechargeAt;
  final int emeralds;
  final int streakCount;
  final Set<String> studyDays;
  final DateTime? xpBoostUntil;

  bool get hasActiveXpBoost =>
      xpBoostUntil != null && xpBoostUntil!.isAfter(DateTime.now());

  factory GameState.fromJson(Map<String, dynamic> json) {
    final rawBoostEnd = json['xpBoostUntil']?.toString();
    return GameState(
      hearts: int.tryParse(json['hearts'].toString()) ?? 5,
      heartRechargeAt: json['heartRechargeAt'] == null
          ? null
          : DateTime.tryParse(json['heartRechargeAt'].toString()),
      emeralds: int.tryParse(json['emeralds'].toString()) ?? 100,
      streakCount: int.tryParse(json['streakCount'].toString()) ?? 0,
      studyDays: (json['studyDays'] as List<dynamic>? ?? [])
          .map((day) => day.toString())
          .toSet(),
      xpBoostUntil: rawBoostEnd == null || rawBoostEnd == 'null'
          ? null
          : DateTime.tryParse(rawBoostEnd),
    );
  }
}

class LessonStartResult {
  const LessonStartResult({required this.lessonAllowed, required this.state});

  final bool lessonAllowed;
  final GameState state;
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
  final List<LessonQuestion> nextQuestions;
}

class LessonQuestion {
  const LessonQuestion({required this.id, required this.question});

  final String id;
  final String question;

  factory LessonQuestion.fromJson(Map<String, dynamic> json) {
    return LessonQuestion(
      id: json['id'].toString(),
      question: json['question'].toString(),
    );
  }
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
