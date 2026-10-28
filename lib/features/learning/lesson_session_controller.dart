import 'package:flutter/foundation.dart';
import '../../models/app_models.dart';
import 'lesson_exercises.dart';

/// Owns lesson I/O and authoritative results. Answer selection/navigation remain
/// presentation state; dependencies are injected so no widget or HTTP is needed.
class LessonSessionController extends ChangeNotifier {
  LessonSessionController({
    required this.loadContent,
    required this.loadAttempts,
    required this.recordAttempt,
    required this.complete,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;
  final Future<LessonContent> Function() loadContent;
  final Future<Map<int, bool?>> Function() loadAttempts;
  final Future<bool> Function(int index, String answer) recordAttempt;
  final Future<LessonCompletion> Function(int correct, int count, int duration)
  complete;
  final DateTime Function() _clock;
  LessonContent? lesson;
  String? loadError;
  bool loading = true;
  bool isChecking = false;
  bool isCompleting = false;
  LessonCompletion? completion;
  DateTime? _startedAt;
  final Map<int, bool?> _attempts = {};
  final Map<int, bool> _grades = {};
  Map<int, bool?> get attemptedResults => Map.unmodifiable(_attempts);
  int get correctCount => _grades.values.where((correct) => correct).length;
  int get elapsedSeconds =>
      _startedAt == null ? 0 : _clock().difference(_startedAt!).inSeconds;
  int _version = 0;
  bool _disposed = false;
  Future<LessonCompletion?>? _finishing;

  Future<Map<int, bool?>> _optionalAttempts() async {
    try {
      return await loadAttempts();
    } catch (_) {
      return {};
    } // Tutor status must not prevent lesson loading.
  }

  Future<bool> load() async {
    if (_disposed) return false;
    final version = ++_version;
    loading = true;
    loadError = null;
    notifyListeners();
    final attempts = _optionalAttempts();
    try {
      final content = await loadContent();
      if (content.exercises.isEmpty) {
        throw AuthException('No exercises are available for this lesson yet.');
      }
      final previous = await attempts;
      if (_disposed || version != _version) return false;
      lesson = LessonContent(
        content: content.content,
        exercises: List.unmodifiable(content.exercises),
      );
      _attempts
        ..clear()
        ..addAll(previous);
      _grades.clear();
      _startedAt = _clock();
      completion = null;
      return true;
    } catch (error) {
      if (_disposed || version != _version) return false;
      loadError = error is AuthException
          ? error.message
          : 'Could not load lesson exercises.';
      return false;
    } finally {
      if (!_disposed && version == _version) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool?> submit(int index, String answer) async {
    if (_disposed || loading || isChecking || lesson == null) return null;
    if (index < 0 || index >= lesson!.exercises.length) {
      throw RangeError.index(index, lesson!.exercises);
    }
    if (_grades.containsKey(index)) return _grades[index];
    final version = _version;
    isChecking = true;
    notifyListeners();
    try {
      final correct = await recordAttempt(index, answer);
      if (_disposed || version != _version) return null;
      _grades[index] = correct;
      _attempts[index] = correct;
      return correct;
    } finally {
      if (!_disposed && version == _version) {
        isChecking = false;
        notifyListeners();
      }
    }
  }

  Future<LessonCompletion?> finish() {
    if (_disposed) return Future.value(null);
    if (completion != null) return Future.value(completion);
    return _finishing ??= _finish().whenComplete(() => _finishing = null);
  }

  Future<LessonCompletion?> _finish() async {
    final count = lesson?.exercises.length ?? 0;
    if (count == 0 || _grades.length != count) {
      throw StateError('Answer every exercise before finishing.');
    }
    final version = _version;
    isCompleting = true;
    notifyListeners();
    try {
      final result = await complete(correctCount, count, elapsedSeconds);
      if (_disposed || version != _version) return null;
      return completion = result;
    } finally {
      if (!_disposed && version == _version) {
        isCompleting = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _version++;
    super.dispose();
  }
}
