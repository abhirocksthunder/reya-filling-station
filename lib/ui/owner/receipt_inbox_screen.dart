import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../l10n/app_strings.dart';
import '../../models/receipt_scan.dart';
import '../../services/station_state_provider.dart';
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
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Administrative evidence import modal.')),
                  );
                },
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
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: r.validationStatus == ReceiptValidationStatus.valid
                                    ? StationColors.warningBg
                                    : Colors.grey.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                r.validationStatus == ReceiptValidationStatus.valid ? 'Pending review' : 'Accepted reading',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: r.validationStatus == ReceiptValidationStatus.valid ? StationColors.warningAmber : Colors.black54,
                                ),
                              ),
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
                'Pump ${scan.fpId} • Receipt review',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: StationColors.textDark),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Historical sample: ${scan.printedDate}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Printout and Metadata Columns
          LayoutBuilder(
            builder: (context, c) {
              bool isStacked = c.maxWidth < 600;

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

              Widget metadataView = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMetaRow('Captured by', scan.capturedBy),
                  _buildMetaRow('Date on receipt', scan.printedDate),
                  _buildMetaRow('Time on receipt', scan.printedTime),
                  _buildMetaRow('Time received', '9 Oct 2026 21:51'),
                  _buildMetaRow('Location', 'Not a verified geolocation (simulated)', isLocation: true),
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
                    metadataView,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: printoutView),
                  const SizedBox(width: 20),
                  Expanded(flex: 5, child: metadataView),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Warning Callout
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: StationColors.warningBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: StationColors.warningBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: StationColors.warningAmber, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Not valid as a new 10 Oct reading',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: StationColors.warningAmber),
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
          ),
          const SizedBox(height: 20),

          // Actions
          Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.open_in_new, size: 16, color: Colors.white),
                label: const Text('Open original image', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: StationColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Opening full resolution stored receipt image.')),
                  );
                },
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Request new photo'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Push notification dispatched to attendant for retake.')),
                  );
                },
              ),
            ],
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
}
