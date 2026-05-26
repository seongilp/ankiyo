class AnkiField {
  final String name;
  final int ord;
  const AnkiField({required this.name, required this.ord});

  factory AnkiField.fromJson(Map<String, dynamic> j) =>
      AnkiField(name: j['name'] as String, ord: (j['ord'] as num).toInt());
}

class AnkiTemplate {
  final String name;
  final int ord;
  final String qfmt;
  final String afmt;
  const AnkiTemplate(
      {required this.name,
      required this.ord,
      required this.qfmt,
      required this.afmt});

  factory AnkiTemplate.fromJson(Map<String, dynamic> j) => AnkiTemplate(
        name: j['name'] as String? ?? '',
        ord: (j['ord'] as num).toInt(),
        qfmt: j['qfmt'] as String? ?? '',
        afmt: j['afmt'] as String? ?? '',
      );
}

class AnkiModel {
  final int id;
  final String name;
  final int type; // 0 = standard, 1 = cloze
  final String css;
  final List<AnkiField> fields;
  final List<AnkiTemplate> templates;

  const AnkiModel({
    required this.id,
    required this.name,
    required this.type,
    required this.css,
    required this.fields,
    required this.templates,
  });

  bool get isCloze => type == 1;

  factory AnkiModel.fromJson(Map<String, dynamic> j) {
    final flds = (j['flds'] as List? ?? [])
        .map((e) => AnkiField.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => a.ord.compareTo(b.ord));
    final tmpls = (j['tmpls'] as List? ?? [])
        .map((e) => AnkiTemplate.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => a.ord.compareTo(b.ord));
    return AnkiModel(
      id: (j['id'] as num).toInt(),
      name: j['name'] as String? ?? '',
      type: (j['type'] as num?)?.toInt() ?? 0,
      css: j['css'] as String? ?? '',
      fields: flds,
      templates: tmpls,
    );
  }
}
