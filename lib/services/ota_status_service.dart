import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

/// Metadata only. Shorebird's background updater owns download/activation.
abstract interface class PatchReader {
  bool get available;
  Future<int?> current();
  Future<int?> pending();
}

class ShorebirdPatchReader implements PatchReader {
  ShorebirdPatchReader() : _updater = ShorebirdUpdater();
  final ShorebirdUpdater _updater;
  @override
  bool get available => !kIsWeb && _updater.isAvailable;
  @override
  Future<int?> current() async => (await _updater.readCurrentPatch())?.number;
  @override
  Future<int?> pending() async => (await _updater.readNextPatch())?.number;
}

class OtaStatusService extends ChangeNotifier {
  OtaStatusService({PatchReader? reader})
    : _reader = reader ?? ShorebirdPatchReader();
  final PatchReader _reader;
  int? appliedPatch;
  int? downloadedPatch;
  String status = 'Not checked';
  bool _reading = false;
  bool _disposed = false;

  Future<void> refresh() async {
    if (_reading || _disposed) return;
    _reading = true;
    try {
      if (!_reader.available) {
        status = 'Unavailable in this build';
      } else {
        final current = await _reader.current();
        final next = await _reader.pending();
        appliedPatch = current;
        downloadedPatch = next == current ? null : next;
        status = downloadedPatch == null
            ? 'Running installed code'
            : 'Downloaded; applies on next cold launch';
      }
    } catch (_) {
      // Keep the last known metadata. Never interfere with station work.
      status = 'Patch status temporarily unavailable';
    } finally {
      _reading = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
