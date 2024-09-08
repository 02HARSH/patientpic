class ImageModel {
  final int? id;
  final String path;
  final String mobile;
  final String? documentPath; // New field for document path

  ImageModel({this.id, required this.path, required this.mobile, this.documentPath});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'path': path,
      'mobile': mobile,
      'documentPath': documentPath,
    };
  }

  factory ImageModel.fromMap(Map<String, dynamic> map) {
    return ImageModel(
      id: map['id'],
      path: map['path'],
      mobile: map['mobile'],
      documentPath: map['documentPath'],
    );
  }

  @override
  String toString() {
    return 'Image{id: $id, path: $path, mobile: $mobile, documentPath: $documentPath}';
  }
}
