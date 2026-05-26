import 'anki_model.dart';

const fieldSeparator = '\x1f';

class AnkiNote {
  final int id;
  final int mid; // model id
  final String fieldsRaw;
  const AnkiNote({required this.id, required this.mid, required this.fieldsRaw});

  Map<String, String> fieldMap(AnkiModel model) {
    final values = fieldsRaw.split(fieldSeparator);
    final map = <String, String>{};
    for (final f in model.fields) {
      map[f.name] = f.ord < values.length ? values[f.ord] : '';
    }
    return map;
  }
}
