import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:reya_filling_station/services/ota_status_service.dart';

class FakeReader implements PatchReader {
  @override
  bool available = true;
  int? applied;
  int? next;
  bool fail = false;
  Completer<int?>? blocked;
  @override
  Future<int?> current() async {
    if (fail) throw StateError('offline');
    return blocked == null ? applied : blocked!.future;
  }

  @override
  Future<int?> pending() async => next;
}

void main() {
  test('downloaded patch remains separate from applied patch', () async {
    final reader = FakeReader()
      ..applied = 1
      ..next = 2;
    final service = OtaStatusService(reader: reader);
    await service.refresh();
    expect(service.appliedPatch, 1);
    expect(service.downloadedPatch, 2);
    reader.applied = 2;
    await service.refresh();
    expect(service.appliedPatch, 2);
    expect(service.downloadedPatch, isNull);
    service.dispose();
  });
  test('base and no-update builds have no pending patch', () async {
    final reader = FakeReader();
    final service = OtaStatusService(reader: reader);
    await service.refresh();
    expect(service.appliedPatch, isNull);
    expect(service.downloadedPatch, isNull);
    reader.available = false;
    await service.refresh();
    expect(service.status, 'Unavailable in this build');
    service.dispose();
  });
  test('offline metadata failure retains installed patch', () async {
    final reader = FakeReader()..applied = 3;
    final service = OtaStatusService(reader: reader);
    await service.refresh();
    reader.fail = true;
    await service.refresh();
    expect(service.appliedPatch, 3);
    expect(service.status, 'Patch status temporarily unavailable');
    service.dispose();
  });
  test('disposal during asynchronous read does not notify', () async {
    final reader = FakeReader()..blocked = Completer<int?>();
    final service = OtaStatusService(reader: reader);
    final refresh = service.refresh();
    service.dispose();
    reader.blocked!.complete(1);
    await refresh;
  });
}
