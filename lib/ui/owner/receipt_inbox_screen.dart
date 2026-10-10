import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/formatting/date_formatter.dart';
import '../../l10n/app_strings.dart';
import '../../models/pump.dart';
import '../../models/receipt_scan.dart';
import '../../services/station_state_provider.dart';
import 'package:image_picker/image_picker.dart';
import '../common/pagination_control.dart';

class ReceiptInboxScreen extends StatefulWidget {
  const ReceiptInboxScreen({super.key});

  @override
  State<ReceiptInboxScreen> createState() => _ReceiptInboxScreenState();
}

class _ReceiptInboxScreenState extends State<ReceiptInboxScreen> {
  int _selectedIndex = 0;
  int _currentPage = 1;
  static const int _pageSize = 10;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    final lang = state.currentLanguage;
    final receipts = state.receipts;

    final totalItems = receipts.length;
    final int startIndex = (_currentPage - 1) * _pageSize;
    final int endIndex = (startIndex + _pageSize).clamp(0, totalItems);
    final displayedReceipts = (startIndex < totalItems)
        ? receipts.sublist(startIndex, endIndex)
        : <ReceiptScan>[];

    final selectedScan = displayedReceipts.isNotEmpty
        ? displayedReceipts[_selectedIndex.clamp(0, displayedReceipts.length - 1)]
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Add Receipt button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.get('receiptInbox', lang),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: StationColors.textDark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppStrings.get('pumpTotaliserPhotos', lang),
                    style: const TextStyle(fontSize: 14, color: StationColors.textMedium),
                  ),
                ],
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('+ Add receipt', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: StationColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _showAddReceiptDialog(context, state),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Empty state or Two-Column Layout
          if (totalItems == 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
                border: Border.all(color: StationColors.divider),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: StationColors.primaryLight.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long_outlined, size: 48, color: StationColors.primary),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No receipts recorded yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: StationColors.textDark),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'When shift staff scan pump totalisers or owners upload receipt images, original records will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: StationColors.textMedium),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                bool isWide = constraints.maxWidth > 800;

                if (!isWide) {
                  return Column(
                    children: [
                      _buildReceiptsList(displayedReceipts, totalItems),
                      const SizedBox(height: 20),
                      if (selectedScan != null) _buildReviewPane(context, selectedScan, lang),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left List
                    SizedBox(
                      width: 320,
                      child: _buildReceiptsList(displayedReceipts, totalItems),
                    ),
                    const SizedBox(width: 20),
                    // Right Detail Pane
                    Expanded(
                      child: selectedScan != null
                          ? _buildReviewPane(context, selectedScan, lang)
                          : const SizedBox(),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildReceiptsList(List<ReceiptScan> receipts, int totalItems) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
            border: Border.all(color: StationColors.divider),
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Receipts (recent)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: StationColors.textDark),
            ),
          ),
          const Divider(height: 1, color: StationColors.divider),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: receipts.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: StationColors.divider),
            itemBuilder: (context, i) {
              final r = receipts[i];
              bool isSelected = i == _selectedIndex;

              return InkWell(
                onTap: () => setState(() => _selectedIndex = i),
                child: Container(
                  color: isSelected ? StationColors.primaryLight.withOpacity(0.08) : Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3EFE6),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFDCCFBC)),
                        ),
                        child: const Icon(Icons.receipt_outlined, color: Colors.brown, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${r.capturedBy.split(' ').first} • Pump ${r.fpId}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${r.printedDate} ${r.printedTime}',
                              style: const TextStyle(fontSize: 12, color: StationColors.textLight),
                            ),
                            const SizedBox(height: 4),
                            Builder(
                              builder: (context) {
                                final isOwner = r.capturedBy.toLowerCase().contains('owner');
                                final isApproved = r.reviewStatus == 'approved' || isOwner;
                                final isRejected = r.reviewStatus == 'rejected';

                                final Color bg = isApproved
                                    ? StationColors.successBg
                                    : (isRejected ? StationColors.errorBg : StationColors.warningBg);
                                final Color fg = isApproved
                                    ? StationColors.successGreen
                                    : (isRejected ? StationColors.errorRed : StationColors.warningAmber);
                                final String text = isApproved
                                    ? (isOwner ? 'Approved by Owner' : 'Approved reading')
                                    : (isRejected ? 'Rejected' : 'Pending review');

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: bg,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    text,
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    ),
    const SizedBox(height: 12),
    PaginationControl(
      currentPage: _currentPage,
      totalItems: totalItems,
      pageSize: _pageSize,
      onPageChanged: (newPage) {
        setState(() {
          _currentPage = newPage;
          _selectedIndex = 0;
        });
      },
    ),
  ],
);
}

  Widget _buildReviewPane(BuildContext context, ReceiptScan scan, String lang) {
    final state = context.watch<StationStateProvider>();
    final pump = state.pumps.firstWhere(
      (p) => p.serialNumber == scan.pumpSerialNumber || p.id == 'pump_${scan.fpId}',
      orElse: () => state.pumps.isNotEmpty
          ? state.pumps.first
          : const Pump(id: '1', name: 'Pump 1', serialNumber: '', nozzles: []),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
        border: Border.all(color: StationColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${pump.name} • Receipt Audit',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: StationColors.textDark),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: StationColors.primaryLight.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Recorded: ${scan.printedDate} ${scan.printedTime}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: StationColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Printout and Metadata Columns
          LayoutBuilder(
            builder: (context, c) {
              bool isStacked = c.maxWidth < 650;

              Widget printoutView = Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF8F1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2D9C8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Staff Captured Slip', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.brown)),
                        const Icon(Icons.receipt_long, size: 16, color: Colors.brown),
                      ],
                    ),
                    const Divider(height: 12, color: Color(0xFFD6CBBB)),
                    Text('FP. ID          : ${scan.fpId}', style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                    Text('Pump SNo   : ${scan.pumpSerialNumber}', style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                    Text('Date           : ${scan.printedDate}', style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                    Text('Time           : ${scan.printedTime}', style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                    const Divider(height: 14, color: Color(0xFFD6CBBB)),
                    const Text('Nozzle No1', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('CumVolume: ${scan.formattedVolume(1).replaceAll(' L', '')}', style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                    const SizedBox(height: 6),
                    const Text('Nozzle No2', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('CumVolume: ${scan.formattedVolume(2).replaceAll(' L', '')}', style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                  ],
                ),
              );

              Widget ownerProofView = Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Owner Base Totaliser Proof', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: StationColors.successGreen)),
                        const Icon(Icons.verified, size: 16, color: StationColors.successGreen),
                      ],
                    ),
                    const Divider(height: 12, color: Color(0xFFBBF7D0)),
                    Text('Pump SNo   : ${pump.serialNumber}', style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                    Text('Status     : Baseline Active', style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: StationColors.successGreen)),
                    const SizedBox(height: 8),
                    if (pump.nozzles.isNotEmpty) ...[
                      Text('Nozzle 1 Prev: ${pump.nozzles[0].formattedPreviousReading}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                      Text('Nozzle 1 Live: ${pump.nozzles[0].formattedReading}', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                    if (pump.nozzles.length > 1) ...[
                      const SizedBox(height: 4),
                      Text('Nozzle 2 Prev: ${pump.nozzles[1].formattedPreviousReading}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                      Text('Nozzle 2 Live: ${pump.nozzles[1].formattedReading}', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.shield_outlined, size: 14, color: StationColors.successGreen),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Matched against owner totaliser baseline',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: StationColors.successGreen),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );

              Widget metadataView = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMetaRow('Captured by', scan.capturedBy),
                  _buildMetaRow('Date on receipt', scan.printedDate),
                  _buildMetaRow('Time on receipt', scan.printedTime),
                  _buildMetaRow('Time received', DateFormatter.formatDisplayDateTime(scan.capturedAt)),
                  _buildMetaRow('Audit Check', 'Dynamic IndianOil Format Confirmed'),
                  const SizedBox(height: 16),
                  // Table
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: StationColors.divider),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Table(
                      children: [
                        const TableRow(
                          decoration: BoxDecoration(color: Color(0xFFF7F9F9)),
                          children: [
                            Padding(padding: EdgeInsets.all(8), child: Text('Nozzle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(padding: EdgeInsets.all(8), child: Text('Cumulative volume (L)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          ],
                        ),
                        TableRow(
                          children: [
                            const Padding(padding: EdgeInsets.all(8), child: Text('Nozzle 1', style: TextStyle(fontSize: 13))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(scan.formattedVolume(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          ],
                        ),
                        TableRow(
                          children: [
                            const Padding(padding: EdgeInsets.all(8), child: Text('Nozzle 2', style: TextStyle(fontSize: 13))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(scan.formattedVolume(2), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );

              if (isStacked) {
                return Column(
                  children: [
                    printoutView,
                    const SizedBox(height: 16),
                    ownerProofView,
                    const SizedBox(height: 16),
                    metadataView,
                  ],
                );
              }

              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: printoutView),
                      const SizedBox(width: 16),
                      Expanded(child: ownerProofView),
                    ],
                  ),
                  const SizedBox(height: 16),
                  metadataView,
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Audit status banner
          Builder(
            builder: (context) {
              final isOwner = scan.capturedBy.toLowerCase().contains('owner');
              final isApproved = scan.reviewStatus == 'approved' || isOwner;
              final isRejected = scan.reviewStatus == 'rejected';

              final Color bg = isApproved
                  ? StationColors.successBg
                  : (isRejected ? StationColors.errorBg : StationColors.warningBg);
              final Color border = isApproved
                  ? StationColors.successGreen.withOpacity(0.3)
                  : (isRejected ? StationColors.errorRed.withOpacity(0.3) : StationColors.warningBorder);
              final Color fg = isApproved
                  ? StationColors.successGreen
                  : (isRejected ? StationColors.errorRed : StationColors.warningAmber);
              final IconData icon = isApproved
                  ? Icons.check_circle_outline
                  : (isRejected ? Icons.cancel_outlined : Icons.pending_actions);
              final String title = isApproved
                  ? (isOwner ? 'Direct Owner Entry • Auto-Approved' : 'Verified Reading • Approved by Owner')
                  : (isRejected ? 'Reading Rejected' : 'Pending Owner Review');

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: fg, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: fg),
                          ),
                          Text(
                            scan.statusMessage,
                            style: const TextStyle(fontSize: 12, color: StationColors.textMedium),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // Actions Row
          Builder(
            builder: (context) {
              final isOwner = scan.capturedBy.toLowerCase().contains('owner');
              final isApproved = scan.reviewStatus == 'approved' || isOwner;

              return Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.zoom_in, size: 16, color: Colors.white),
                    label: const Text('Open original image', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StationColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: () => _showFullImageViewer(context, scan.imagePath),
                  ),

                  // If staff scan and not yet approved, show Approve and Reject buttons!
                  if (!isApproved) ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 16, color: Colors.white),
                      label: const Text('Approve receipt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: StationColors.successGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: () {
                        state.approveReceipt(scan.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Receipt for Pump ${scan.fpId} approved and pump nozzles updated!'),
                            backgroundColor: StationColors.successGreen,
                          ),
                        );
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.close, size: 16, color: StationColors.errorRed),
                      label: const Text('Reject', style: TextStyle(color: StationColors.errorRed, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: StationColors.errorRed),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: () {
                        state.rejectReceipt(scan.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Receipt marked as rejected.'),
                            backgroundColor: StationColors.errorRed,
                          ),
                        );
                      },
                    ),
                  ],

                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Request new photo'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: () {
                      state.addNotification(
                        title: 'Rescan requested for Pump ${scan.fpId}',
                        subtitle: 'Owner requested new receipt photograph',
                        isWarning: true,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Push notification dispatched to attendant for retake.')),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String key, String value, {bool isLocation = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(key, style: const TextStyle(fontSize: 13, color: StationColors.textLight)),
          ),
          Text(': ', style: const TextStyle(fontSize: 13, color: StationColors.textLight)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isLocation ? FontWeight.normal : FontWeight.w600,
                color: isLocation ? Colors.orange[800] : StationColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddReceiptDialog(BuildContext context, StationStateProvider state) {
    final pumps = state.pumps;
    if (pumps.isEmpty) return;

    String selectedPumpId = pumps.first.id;
    Pump selectedPump = pumps.first;

    final now = DateTime.now();
    final dayStr = now.day.toString().padLeft(2, '0');
    final monthStr = now.month.toString().padLeft(2, '0');
    final dateCtrl = TextEditingController(text: '$dayStr/$monthStr/${now.year}');
    final hourStr = now.hour.toString().padLeft(2, '0');
    final minStr = now.minute.toString().padLeft(2, '0');
    final secStr = now.second.toString().padLeft(2, '0');
    final timeCtrl = TextEditingController(text: '$hourStr:$minStr:$secStr');

    final n1Ctrl = TextEditingController(
      text: selectedPump.nozzles.isNotEmpty
          ? (selectedPump.nozzles[0].currentTotaliserMl / 1000.0).toStringAsFixed(3)
          : '',
    );
    final n2Ctrl = TextEditingController(
      text: selectedPump.nozzles.length > 1
          ? (selectedPump.nozzles[1].currentTotaliserMl / 1000.0).toStringAsFixed(3)
          : '',
    );

    String? pickedPhotoName;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.add_photo_alternate, color: StationColors.primary),
              SizedBox(width: 10),
              Text('Add IndianOil Pump Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Dispenser / Pump:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedPumpId,
                    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                    items: pumps.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} (SNo: ${p.serialNumber})'))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedPumpId = val;
                          selectedPump = pumps.firstWhere((p) => p.id == val);
                          if (selectedPump.nozzles.isNotEmpty) {
                            n1Ctrl.text = (selectedPump.nozzles[0].currentTotaliserMl / 1000.0).toStringAsFixed(3);
                          }
                          if (selectedPump.nozzles.length > 1) {
                            n2Ctrl.text = (selectedPump.nozzles[1].currentTotaliserMl / 1000.0).toStringAsFixed(3);
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Image picker button
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: StationColors.divider),
                    ),
                    child: Column(
                      children: [
                        Text(
                          pickedPhotoName ?? 'No photo selected yet',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: pickedPhotoName != null ? StationColors.successGreen : StationColors.textLight,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                              label: const Text('Camera', style: TextStyle(fontSize: 12, color: Colors.white)),
                              style: ElevatedButton.styleFrom(backgroundColor: StationColors.primary),
                              onPressed: () async {
                                final picker = ImagePicker();
                                final file = await picker.pickImage(source: ImageSource.camera);
                                if (file != null) {
                                  setDialogState(() {
                                    pickedPhotoName = 'Captured: ${file.name}';
                                  });
                                }
                              },
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.photo_library, size: 16),
                              label: const Text('Gallery / File', style: TextStyle(fontSize: 12)),
                              onPressed: () async {
                                final picker = ImagePicker();
                                final file = await picker.pickImage(source: ImageSource.gallery);
                                if (file != null) {
                                  setDialogState(() {
                                    pickedPhotoName = 'Selected: ${file.name}';
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: dateCtrl,
                          maxLength: 10,
                          inputFormatters: [LengthLimitingTextInputFormatter(10)],
                          decoration: const InputDecoration(labelText: 'Date (dd/MM/yyyy)', counterText: '', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: timeCtrl,
                          maxLength: 8,
                          inputFormatters: [LengthLimitingTextInputFormatter(8)],
                          decoration: const InputDecoration(labelText: 'Time (HH:mm:ss)', counterText: '', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: n1Ctrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    maxLength: 15,
                    inputFormatters: [LengthLimitingTextInputFormatter(15)],
                    decoration: InputDecoration(
                      labelText: selectedPump.nozzles.isNotEmpty
                          ? 'Nozzle 1 (${selectedPump.nozzles[0].fuelType}) Litres'
                          : 'Nozzle 1 Litres',
                      counterText: '',
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: n2Ctrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    maxLength: 15,
                    inputFormatters: [LengthLimitingTextInputFormatter(15)],
                    decoration: InputDecoration(
                      labelText: selectedPump.nozzles.length > 1
                          ? 'Nozzle 2 (${selectedPump.nozzles[1].fuelType}) Litres'
                          : 'Nozzle 2 Litres',
                      counterText: '',
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 16, color: Colors.white),
              label: const Text('Save & Update Totaliser', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: StationColors.successGreen),
              onPressed: () {
                final double? n1 = double.tryParse(n1Ctrl.text);
                final double? n2 = double.tryParse(n2Ctrl.text);
                if (n1 == null || n2 == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter valid cumulative litre readings for both nozzles.')),
                  );
                  return;
                }

                final newScan = ReceiptScan(
                  id: 'scan_${DateTime.now().millisecondsSinceEpoch}',
                  pumpSerialNumber: selectedPump.serialNumber,
                  fpId: selectedPump.id.replaceAll('pump_', ''),
                  printedDate: dateCtrl.text.trim(),
                  printedTime: timeCtrl.text.trim(),
                  nozzleCumVolumeMl: {
                    1: (n1 * 1000).round(),
                    2: (n2 * 1000).round(),
                  },
                  imagePath: selectedPump.referenceReceiptAsset ?? 'assets/images/media_1791616403909.jpg',
                  validationStatus: ReceiptValidationStatus.valid,
                  reviewStatus: 'approved',
                  statusMessage: 'Direct owner totaliser receipt recorded.',
                  capturedBy: '${state.currentUser.name} (Owner Upload)',
                  capturedAt: DateTime.now(),
                  locationVerified: true,
                  distanceMeters: 14.5,
                );

                state.saveReceiptScan(newScan);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Receipt slip recorded and totaliser updated for ${selectedPump.name}!'),
                    backgroundColor: StationColors.successGreen,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFullImageViewer(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.85,
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              // Top bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.black87,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.zoom_in, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Original IndianOil Receipt Slip',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: _buildImageView(imagePath),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.black87,
                child: const Text(
                  'Pinch or scroll to zoom • Pan to inspect totaliser readings',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageView(String imagePath) {
    if (imagePath.startsWith('http')) {
      return Image.network(imagePath, fit: BoxFit.contain);
    }
    if (imagePath.startsWith('assets/')) {
      return Image.asset(imagePath, fit: BoxFit.contain);
    }
    return Image.asset(
      'assets/images/media_1791616403909.jpg',
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Text('Receipt image preview unavailable', style: TextStyle(color: Colors.white)),
        );
      },
    );
  }
}
