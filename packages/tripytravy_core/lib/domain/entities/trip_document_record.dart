/// Trip Document and Information record exported from the Agent side or attached to day events.
class TripDocumentRecord {
  final String id;
  final String title;
  final String docType;
  final String description;
  final String fileName;
  final String fileSize;
  final String filePath;
  final String? locationName;
  final String? mapUrl;
  final String? base64Data;

  const TripDocumentRecord({
    required this.id,
    required this.title,
    this.docType = 'general',
    this.description = '',
    this.fileName = '',
    this.fileSize = '',
    this.filePath = '',
    this.locationName,
    this.mapUrl,
    this.base64Data,
  });

  TripDocumentRecord copyWith({
    String? id,
    String? title,
    String? docType,
    String? description,
    String? fileName,
    String? fileSize,
    String? filePath,
    String? locationName,
    String? mapUrl,
    String? base64Data,
  }) {
    return TripDocumentRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      docType: docType ?? this.docType,
      description: description ?? this.description,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      filePath: filePath ?? this.filePath,
      locationName: locationName ?? this.locationName,
      mapUrl: mapUrl ?? this.mapUrl,
      base64Data: base64Data ?? this.base64Data,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'docType': docType,
        'description': description,
        'fileName': fileName,
        'fileSize': fileSize,
        'filePath': filePath,
        if (locationName != null) 'locationName': locationName,
        if (mapUrl != null) 'mapUrl': mapUrl,
        if (base64Data != null) 'base64Data': base64Data,
      };

  factory TripDocumentRecord.fromJson(Map<String, dynamic> json) =>
      TripDocumentRecord(
        id: (json['id'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        docType: (json['docType'] as String?) ?? 'general',
        description: (json['description'] as String?) ?? '',
        fileName: (json['fileName'] as String?) ?? '',
        fileSize: (json['fileSize'] as String?) ?? '',
        filePath: (json['filePath'] as String?) ?? '',
        locationName: json['locationName'] as String?,
        mapUrl: json['mapUrl'] as String?,
        base64Data: json['base64Data'] as String?,
      );
}
