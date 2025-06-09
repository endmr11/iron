abstract class PersistenceAdapter<T> {
  Future<void> save(Map<String, dynamic> json);
  Future<Map<String, dynamic>?> load();
  Future<void> clear();
}
