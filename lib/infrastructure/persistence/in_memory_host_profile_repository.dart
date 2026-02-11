import 'package:small_ssh/domain/models/host_profile.dart';
import 'package:small_ssh/domain/repositories/host_profile_repository.dart';

class InMemoryHostProfileRepository implements HostProfileRepository {
  final Map<String, HostProfile> _items = <String, HostProfile>{
    'local-dev': const HostProfile(
      id: 'local-dev',
      name: 'Local Dev Server',
      host: '127.0.0.1',
      port: 22,
      username: 'developer',
    ),
    'demo-box': const HostProfile(
      id: 'demo-box',
      name: 'Demo Host',
      host: '192.168.1.100',
      port: 22,
      username: 'root',
    ),
  };

  @override
  Future<HostProfile?> findById(String id) async {
    return _items[id];
  }

  @override
  Future<List<HostProfile>> getAll() async {
    return _items.values.toList(growable: false);
  }

  @override
  Future<void> save(HostProfile profile) async {
    _items[profile.id] = profile;
  }
}
