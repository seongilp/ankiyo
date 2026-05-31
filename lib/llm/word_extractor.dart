import 'dart:convert';
import 'anthropic_client.dart';

class ExtractedCard {
  final String word;
  final String pos;
  final String meaning;
  final String example;
  const ExtractedCard({
    required this.word,
    required this.pos,
    required this.meaning,
    required this.example,
  });

  ExtractedCard copyWith({String? word, String? pos, String? meaning, String? example}) =>
      ExtractedCard(
        word: word ?? this.word,
        pos: pos ?? this.pos,
        meaning: meaning ?? this.meaning,
        example: example ?? this.example,
      );
}

class WordExtractor {
  final AnthropicClient client;
  const WordExtractor(this.client);

  static const _system = '''
You are an English vocabulary card builder for Korean learners.

The user input can be:
(A) An English passage — pick important words/phrases worth memorizing
    (academic vocabulary, idioms, useful collocations).
(B) A list with meanings — one per line, "word / 뜻" or "word - 뜻"
    or "word: 뜻" or "word\\t뜻". Convert each line to a card directly
    (do NOT skip or re-pick). Keep the user's "뜻" verbatim. Leave
    "example" empty unless you can confidently infer one from context.
(C) A list of words only — one English word/phrase per line, no Korean
    meanings. Supply the Korean meaning yourself (concise, 1~2 어구).
    Cover every line. Leave "example" empty.

Heuristic: if most lines are a single English token or short phrase with
no Korean characters and no separator, treat as (C). If lines clearly
contain "word + separator + Korean", treat as (B). Otherwise (A).
If input mixes formats, handle line-by-line accordingly.

Output STRICT JSON only. No markdown, no commentary. Schema:
{
  "cards": [
    {"word": "<English word or phrase>",
     "pos": "<품사 한국어: 명사/동사/형용사/부사/숙어/기타. 모르면 \\"기타\\">",
     "meaning": "<한국어 뜻 1~2 짧은 어구>",
     "example": "<본문에서 그 단어가 쓰인 문장 그대로 (없으면 빈 문자열)>"}
  ]
}

Rules:
- For (A) passage mode: extract **at least 20 cards**, up to 40. Aim for ~25–30.
  If the passage is short, include common-but-useful words/phrases to reach 20.
- For (B) list with meanings: output every valid line as a card. Do not invent extras.
- For (C) words-only list: output every line as a card with your Korean meaning.
  Do not invent extra words.
- "example" must be copied verbatim from the input passage when possible.
- Do not invent words that aren't in the input.
- Korean meaning should be concise (e.g. "조사하다, 탐구하다").
- No duplicate words.
''';

  Future<List<ExtractedCard>> extract(String passage) async {
    final raw = await client.complete(system: _system, user: passage);
    final jsonStr = _stripFences(raw).trim();
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map || decoded['cards'] is! List) {
      throw AnthropicException('카드 배열을 찾을 수 없어요');
    }
    final list = decoded['cards'] as List;
    return list
        .whereType<Map>()
        .map((m) => ExtractedCard(
              word: (m['word'] ?? '').toString().trim(),
              pos: (m['pos'] ?? '').toString().trim(),
              meaning: (m['meaning'] ?? '').toString().trim(),
              example: (m['example'] ?? '').toString().trim(),
            ))
        .where((c) => c.word.isNotEmpty && c.meaning.isNotEmpty)
        .toList();
  }

  static String _stripFences(String s) {
    final t = s.trim();
    if (!t.startsWith('```')) return t;
    final lines = t.split('\n');
    if (lines.length < 2) return t;
    final body = lines.sublist(1, lines.length - (lines.last.startsWith('```') ? 1 : 0));
    return body.join('\n');
  }
}
