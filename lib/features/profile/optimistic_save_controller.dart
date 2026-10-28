import 'package:flutter/foundation.dart';

/// Owns one optimistic value and its write/rollback lifecycle. Callers choose
/// whether previews are local (avatars) or published immediately (language).
class OptimisticSaveController<T> extends ChangeNotifier {
  OptimisticSaveController({
    required T initialValue,
    required Future<T> Function(T) persist,
  }) : _value = initialValue,
       _persist = persist;

  final Future<T> Function(T) _persist;
  T _value;
  T get value => _value;
  bool _isSaving = false;
  bool get isSaving => _isSaving;
  bool _disposed = false;

  /// Used from didUpdateWidget; its following build already refreshes the UI.
  void synchronize(T value) {
    if (!_disposed && !_isSaving) _value = value;
  }

  Future<bool> save(
    T next, {
    ValueChanged<T>? onPreview,
    ValueChanged<T>? onCommit,
    ValueChanged<T>? onRollback,
  }) async {
    if (_disposed || _isSaving || next == _value) return false;
    final previous = _value;
    _value = next;
    _isSaving = true;
    notifyListeners();
    try {
      onPreview?.call(next);
      final saved = await _persist(next);
      if (_disposed) return false;
      _value = saved;
      onCommit?.call(saved);
      return true;
    } catch (_) {
      if (!_disposed) {
        _value = previous;
        onRollback?.call(previous);
      }
      rethrow;
    } finally {
      if (!_disposed) {
        _isSaving = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
