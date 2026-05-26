import 'anki_model.dart';
import 'anki_note.dart';

class BuiltCard {
  final String frontHtml;
  final String backHtml;
  final bool isCloze;
  const BuiltCard(
      {required this.frontHtml, required this.backHtml, required this.isCloze});
}

class CardBuilder {
  const CardBuilder();

  static final _clozeRe =
      RegExp(r'\{\{c(\d+)::(.*?)(?:::(.*?))?\}\}', dotAll: true);

  BuiltCard build({
    required AnkiNote note,
    required AnkiModel model,
    required int ord,
  }) {
    final fields = note.fieldMap(model);
    final template = _templateForOrd(model, ord);

    if (model.isCloze) {
      final clozeNum = ord + 1;
      final front = _renderCloze(template.qfmt, fields, clozeNum, reveal: false);
      final back = _renderCloze(template.afmt, fields, clozeNum, reveal: true);
      return BuiltCard(frontHtml: front, backHtml: back, isCloze: true);
    }

    final front = _renderTemplate(template.qfmt, fields, frontSide: '');
    final back = _renderTemplate(template.afmt, fields, frontSide: front);
    return BuiltCard(frontHtml: front, backHtml: back, isCloze: false);
  }

  List<int> clozeNumbers(AnkiNote note, AnkiModel model) {
    final nums = <int>{};
    for (final v in note.fieldMap(model).values) {
      for (final m in _clozeRe.allMatches(v)) {
        nums.add(int.parse(m.group(1)!));
      }
    }
    final sorted = nums.toList()..sort();
    return sorted;
  }

  AnkiTemplate _templateForOrd(AnkiModel model, int ord) {
    if (model.isCloze) {
      // cloze는 템플릿이 하나, ord는 클로즈 번호를 의미
      return model.templates.isNotEmpty
          ? model.templates.first
          : const AnkiTemplate(
              name: '', ord: 0, qfmt: '{{cloze:Text}}', afmt: '{{cloze:Text}}');
    }
    return model.templates.firstWhere((t) => t.ord == ord,
        orElse: () => model.templates.first);
  }

  // --- 표준 템플릿 렌더링 ---
  String _renderTemplate(String template, Map<String, String> fields,
      {required String frontSide}) {
    var out = _applyConditionals(template, fields);
    out = out.replaceAll('{{FrontSide}}', frontSide);
    out = out.replaceAllMapped(RegExp(r'\{\{([^#^/][^}]*?)\}\}'), (m) {
      final token = m.group(1)!.trim();
      final name = token.contains(':') ? token.split(':').last.trim() : token;
      return fields[name] ?? '';
    });
    return out;
  }

  String _applyConditionals(String tmpl, Map<String, String> fields) {
    final posRe = RegExp(r'\{\{#(\w+)\}\}(.*?)\{\{/\1\}\}', dotAll: true);
    final negRe = RegExp(r'\{\{\^(\w+)\}\}(.*?)\{\{/\1\}\}', dotAll: true);
    var out = tmpl;
    out = out.replaceAllMapped(posRe, (m) {
      final v = fields[m.group(1)] ?? '';
      return v.trim().isNotEmpty ? m.group(2)! : '';
    });
    out = out.replaceAllMapped(negRe, (m) {
      final v = fields[m.group(1)] ?? '';
      return v.trim().isEmpty ? m.group(2)! : '';
    });
    return out;
  }

  // --- cloze 렌더링 ---
  String _renderCloze(String template, Map<String, String> fields, int activeNum,
      {required bool reveal}) {
    // {{cloze:Field}} 토큰을 클로즈 처리한 값으로 치환
    var out = template.replaceAllMapped(RegExp(r'\{\{cloze:(\w+)\}\}'), (m) {
      final raw = fields[m.group(1)] ?? '';
      return _processCloze(raw, activeNum, reveal: reveal);
    });
    // 나머지 일반 필드 ({{Extra}} 등)
    out = out.replaceAllMapped(RegExp(r'\{\{([^#^/][^}]*?)\}\}'), (m) {
      final name = m.group(1)!.trim();
      return fields[name] ?? '';
    });
    return out;
  }

  String _processCloze(String text, int activeNum, {required bool reveal}) {
    return text.replaceAllMapped(_clozeRe, (m) {
      final num = int.parse(m.group(1)!);
      final answer = m.group(2)!;
      final hint = m.group(3);
      if (num == activeNum) {
        if (reveal) return '<span class="cloze">$answer</span>';
        return hint != null && hint.isNotEmpty ? '[$hint]' : '[...]';
      }
      return answer; // 다른 번호의 클로즈는 항상 노출
    });
  }
}
