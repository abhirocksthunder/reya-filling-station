import 'package:flutter/material.dart';
import '../services/app_version_service.dart';
import '../core/constants/colors.dart';

class VersionFooter extends StatefulWidget {
  final bool compact;
  final Color? color;

  const VersionFooter({
    super.key,
    this.compact = false,
    this.color,
  });

  @override
  State<VersionFooter> createState() => _VersionFooterState();
}

class _VersionFooterState extends State<VersionFooter> {
  String _displayVersion = AppVersionService.displayVersion;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    await AppVersionService.init();
    if (mounted) {
      setState(() {
        _displayVersion = AppVersionService.displayVersion;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.color ?? StationColors.textLight.withOpacity(0.8);

    if (widget.compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
        ),
        child: Text(
          _displayVersion,
          softWrap: false,
          style: TextStyle(
            color: textColor,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_outlined, size: 14, color: textColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'RFS · $_displayVersion',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
