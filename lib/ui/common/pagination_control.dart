import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';

class PaginationControl extends StatelessWidget {
  final int currentPage; // 1-indexed
  final int totalItems;
  final int pageSize; // default 10
  final Function(int) onPageChanged;

  const PaginationControl({
    super.key,
    required this.currentPage,
    required this.totalItems,
    this.pageSize = 10,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (totalItems <= 0) return const SizedBox();

    int totalPages = (totalItems / pageSize).ceil();
    if (totalPages < 1) totalPages = 1;

    int startIndex = (currentPage - 1) * pageSize + 1;
    int endIndex = (currentPage * pageSize).clamp(1, totalItems);

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isNarrow = constraints.maxWidth < 650;

        if (isNarrow) {
          // Compact / Column Layout for phone screens and narrow content panels
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: StationColors.divider),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Showing $startIndex–$endIndex of $totalItems',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: StationColors.textMedium,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
                        child: const Text('Prev', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '$currentPage / $totalPages',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
                        child: const Text('Next', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        // Standard Wide Row Layout
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: StationColors.divider),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing $startIndex–$endIndex of $totalItems',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: StationColors.textMedium,
                ),
              ),
              Row(
                children: [
                  SizedBox(
                    height: 44, // 44px+ touch target mandate
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
                      child: const Text('Previous', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'Page $currentPage of $totalPages',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  SizedBox(
                    height: 44, // 44px+ touch target mandate
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
                      child: const Text('Next', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
