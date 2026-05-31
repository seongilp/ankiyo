import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../llm/word_extractor.dart';
import '../../srs/card_state.dart';
import '../../storage/deck_repository.dart';
import '../../storage/models.dart';

enum CreateDeckStage { input, analyzing, review, saving, done }

class CreateDeckController extends ChangeNotifier {
  final DeckRepository repo;
  final WordExtractor extractor;
  final _uuid = const Uuid();

  CreateDeckStage stage = CreateDeckStage.input;
  String? errorMessage;
  List<ExtractedCard> cards = const [];
  String? createdDeckId;

  CreateDeckController({required this.repo, required this.extractor});

  Future<void> analyze(String passage) async {
    if (passage.trim().isEmpty) {
      errorMessage = '본문을 붙여넣어 주세요.';
      notifyListeners();
      return;
    }
    stage = CreateDeckStage.analyzing;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await extractor.extract(passage);
      if (result.isEmpty) {
        errorMessage = '추출된 단어가 없어요. 본문을 확인해 주세요.';
        stage = CreateDeckStage.input;
      } else {
        cards = result;
        stage = CreateDeckStage.review;
      }
    } catch (e) {
      errorMessage = e.toString();
      stage = CreateDeckStage.input;
    }
    notifyListeners();
  }

  void updateCard(int index, ExtractedCard card) {
    final next = [...cards];
    next[index] = card;
    cards = next;
    notifyListeners();
  }

  void removeCard(int index) {
    final next = [...cards]..removeAt(index);
    cards = next;
    notifyListeners();
  }

  Future<void> save(String deckName) async {
    if (deckName.trim().isEmpty) {
      errorMessage = '덱 이름을 입력해 주세요.';
      notifyListeners();
      return;
    }
    if (cards.isEmpty) {
      errorMessage = '저장할 카드가 없어요.';
      notifyListeners();
      return;
    }
    stage = CreateDeckStage.saving;
    notifyListeners();
    try {
      final now = DateTime.now();
      final deck = Deck(id: _uuid.v4(), name: deckName.trim(), importedAt: now);
      final studyCards = cards
          .map((c) => StudyCard(
                id: _uuid.v4(),
                deckId: deck.id,
                frontHtml: _front(c),
                backHtml: _back(c),
                isCloze: false,
                state: CardState.create(now),
              ))
          .toList();
      await repo.saveDeck(deck, studyCards);
      createdDeckId = deck.id;
      stage = CreateDeckStage.done;
    } catch (e) {
      errorMessage = e.toString();
      stage = CreateDeckStage.review;
    }
    notifyListeners();
  }

  static String _front(ExtractedCard c) =>
      '<div style="text-align:center"><div style="font-size:28px;font-weight:700">${_esc(c.word)}</div></div>';

  static String _back(ExtractedCard c) {
    final pos = c.pos.isEmpty ? '' : '<div style="color:#888;font-size:13px;margin-bottom:6px">${_esc(c.pos)}</div>';
    final example = c.example.isEmpty
        ? ''
        : '<div style="margin-top:14px;padding-top:14px;border-top:1px solid #333;color:#aaa;font-style:italic;font-size:14px">${_esc(c.example)}</div>';
    return '<div>$pos<div style="font-size:18px;font-weight:600">${_esc(c.meaning)}</div>$example</div>';
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
