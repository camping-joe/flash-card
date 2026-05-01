class Note {
  final int id;
  final String title;
  final String content;
  final String? sourcePath;
  final String createdAt;
  final String updatedAt;

  Note({
    required this.id,
    required this.title,
    required this.content,
    this.sourcePath,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      sourcePath: json['source_path'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }
}
