import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ota_status_service.dart';

class OtaDiagnostics extends StatelessWidget {
  const OtaDiagnostics({super.key});
  @override
  Widget build(BuildContext context) {
    final ota = context.watch<OtaStatusService?>();
    if (ota == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Applied patch: ${ota.appliedPatch ?? "Base APK"}'),
          Text('Downloaded patch: ${ota.downloadedPatch ?? "None"}'),
          Text(ota.status),
          TextButton(
            onPressed: ota.refresh,
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            child: const Text('Refresh diagnostics'),
          ),
        ],
      ),
    );
  }
}
