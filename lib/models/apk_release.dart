import '../core/formatting/date_formatter.dart';

class ApkReleaseItem {
  final String id;
  final String version;
  final int buildNumber;
  final String downloadUrl;
  final String fileName;
  final int fileSizeBytes;
  final String publishedBy;
  final DateTime publishedAt;
  final String releaseNotes;
  final bool active;

  const ApkReleaseItem({
    required this.id,
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    this.fileName = 'reya-filling-station.apk',
    this.fileSizeBytes = 0,
    this.publishedBy = 'Owner',
    required this.publishedAt,
    this.releaseNotes = '',
    this.active = true,
  });

  String get displayVersion => 'v$version+$buildNumber';

  String get formattedPublishedAt => DateFormatter.formatAipccTimestamp(publishedAt);

  String get formattedSize {
    if (fileSizeBytes <= 0) return '88.4 MB';
    final mb = fileSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  ApkReleaseItem copyWith({
    String? id,
    String? version,
    int? buildNumber,
    String? downloadUrl,
    String? fileName,
    int? fileSizeBytes,
    String? publishedBy,
    DateTime? publishedAt,
    String? releaseNotes,
    bool? active,
  }) {
    return ApkReleaseItem(
      id: id ?? this.id,
      version: version ?? this.version,
      buildNumber: buildNumber ?? this.buildNumber,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      fileName: fileName ?? this.fileName,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      publishedBy: publishedBy ?? this.publishedBy,
      publishedAt: publishedAt ?? this.publishedAt,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      active: active ?? this.active,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'version': version,
    'buildNumber': buildNumber,
    'downloadUrl': downloadUrl,
    'fileName': fileName,
    'fileSizeBytes': fileSizeBytes,
    'publishedBy': publishedBy,
    'publishedAt': publishedAt.toIso8601String(),
    'releaseNotes': releaseNotes,
    'active': active,
  };

  factory ApkReleaseItem.fromMap(Map<String, dynamic> map) => ApkReleaseItem(
    id: map['id'] ?? '',
    version: map['version'] ?? '',
    buildNumber: (map['buildNumber'] as num?)?.toInt() ?? 1,
    downloadUrl: map['downloadUrl'] ?? '',
    fileName: map['fileName'] ?? 'reya-filling-station.apk',
    fileSizeBytes: (map['fileSizeBytes'] as num?)?.toInt() ?? 0,
    publishedBy: map['publishedBy'] ?? 'Owner',
    publishedAt: map['publishedAt'] != null
        ? (DateTime.tryParse(map['publishedAt'].toString()) ?? DateTime.now())
        : DateTime.now(),
    releaseNotes: map['releaseNotes'] ?? '',
    active: map['active'] ?? true,
  );
}
