/// Invalidates old reads when a newer read or authoritative write starts.
class LatestRequest {
  int _version = 0;
  int begin() => ++_version;
  void invalidate() => _version++;
  bool owns(int version) => version == _version;
}
