/// Shared parsing helpers for repositories. Edge Functions return
/// `{ data: … , requestId: … }` via jsonOk(); these helpers unwrap the
/// `data` payload into typed models or throw if the shape is unexpected.
abstract class BaseRepository {
  const BaseRepository();

  Object? rawData(Map<String, dynamic> res) => res['data'];

  List<T> parseList<T>(
      Map<String, dynamic> res, T Function(Map<String, dynamic>) fromJson) {
    final data = res['data'];
    if (data is List) {
      return data.map((e) => fromJson(e as Map<String, dynamic>)).toList();
    }
    if (data is Map<String, dynamic>) return [fromJson(data)];
    return const [];
  }

  T parseObject<T>(
      Map<String, dynamic> res, T Function(Map<String, dynamic>) fromJson) {
    final data = res['data'];
    if (data is List) return fromJson(data.first as Map<String, dynamic>);
    return fromJson(data as Map<String, dynamic>);
  }
}
