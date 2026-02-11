import 'package:small_ssh/domain/models/host_profile.dart';

abstract class HostProfileRepository {
  Future<List<HostProfile>> getAll();
  Future<HostProfile?> findById(String id);
  Future<void> save(HostProfile profile);
}
