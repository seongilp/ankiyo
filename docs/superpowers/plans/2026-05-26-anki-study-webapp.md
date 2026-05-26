# Anki 학습 웹앱 (ankiyo) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `.apkg` Anki 덱을 브라우저에서 읽어 간격 반복(SRS) 방식으로 공부하는 Flutter 웹앱을 만든다.

**Architecture:** 순수 로직(`apkg/` 파싱, `srs/` 스케줄러)은 I/O·UI 없이 단독 테스트 가능하게 분리한다. `.apkg`는 `archive`로 풀고 내부 SQLite(`collection.anki21`)를 `sqlite3`(웹=WASM)로 1회 읽어 카드를 추출한 뒤, `sembast`(IndexedDB)에 저장한다. 이후 런타임은 자체 저장소만 사용한다. 백엔드 없음.

**Tech Stack:** Flutter (web 타깃), `archive`, `sqlite3`, `sembast` + `sembast_web`, `flutter_widget_from_html`, `file_picker`, `provider`, `uuid`.

---

## 파일 구조

```
lib/
├── apkg/
│   ├── anki_model.dart        # AnkiModel/AnkiField/AnkiTemplate (노트타입)
│   ├── anki_note.dart         # AnkiNote/AnkiCardRow (notes/cards 행)
│   ├── card_builder.dart      # 템플릿+필드 → 앞/뒤 HTML, cloze 전개
│   ├── apkg_reader.dart       # zip 해제 → collection DB 바이트 추출
│   └── anki_db.dart           # sqlite3로 col/notes/cards 읽기 → 모델로
├── srs/
│   ├── card_state.dart        # CardState(불변), CardStatus, Rating
│   └── scheduler.dart         # SchedulerConfig + Scheduler.review()
├── storage/
│   ├── db.dart                # sembast Database 오픈(웹/네이티브 분기)
│   ├── models.dart            # StudyCard, Deck (저장 모델, 불변)
│   ├── deck_repository.dart   # 덱·카드 CRUD
│   ├── settings_store.dart    # 일일 한도 설정 저장
│   └── import_service.dart    # apkg → 모델 변환 → 저장 오케스트레이션
├── study/
│   └── review_queue.dart      # 오늘 학습 큐 구성(순수 함수)
├── ui/
│   ├── app.dart               # MaterialApp + 라우팅
│   ├── import_screen.dart
│   ├── deck_list_screen.dart
│   ├── review_screen.dart
│   ├── settings_screen.dart
│   ├── controllers/
│   │   ├── deck_list_controller.dart
│   │   ├── review_controller.dart
│   │   └── settings_controller.dart
│   └── widgets/
│       └── card_view.dart     # HTML 카드 렌더 위젯
└── main.dart
test/
├── srs/scheduler_test.dart
├── srs/card_state_test.dart
├── apkg/card_builder_test.dart
├── apkg/anki_db_test.dart
├── study/review_queue_test.dart
├── storage/deck_repository_test.dart
└── fixtures/                  # 샘플 .apkg, 추출 DB
```

---

## Task 0: 프로젝트 스캐폴딩 & 의존성

**Files:**
- Create: `pubspec.yaml` (flutter create가 생성, 이후 수정)
- Create: `web/sqlite3.wasm` (다운로드)

- [ ] **Step 1: Flutter 설치 확인**

Run: `flutter --version`
Expected: Flutter stable 버전 출력. 없으면 https://docs.flutter.dev/get-started/install 로 설치(또는 `git clone https://github.com/flutter/flutter.git -b stable` 후 PATH 등록) 한 뒤 `flutter doctor` 로 확인.

- [ ] **Step 2: 프로젝트 생성 (현재 디렉토리에)**

Run:
```bash
cd /Users/zihado/work/ankiyo
flutter create --platforms=web --project-name ankiyo .
```
Expected: `lib/main.dart`, `web/`, `pubspec.yaml` 생성. 기존 `docs/`, `.git`은 보존됨.

- [ ] **Step 3: 의존성 추가**

Run:
```bash
flutter pub add archive sqlite3 sembast sembast_web flutter_widget_from_html file_picker provider uuid
flutter pub add --dev flutter_test
```
Expected: `pubspec.yaml`의 dependencies에 위 패키지들이 추가됨.

- [ ] **Step 4: 웹용 sqlite3.wasm 배치**

`sqlite3` 패키지는 웹에서 `sqlite3.wasm` 파일이 필요하다. 설치한 `sqlite3` 패키지 버전에 맞는 wasm을 받아 `web/sqlite3.wasm`에 둔다.

Run:
```bash
DARTVER=$(flutter pub deps --style=compact 2>/dev/null | grep -m1 'sqlite3 ' | awk '{print $2}')
echo "sqlite3 package version: $DARTVER"
curl -L -o web/sqlite3.wasm "https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-$DARTVER/sqlite3.wasm"
ls -la web/sqlite3.wasm
```
Expected: `web/sqlite3.wasm`가 수백 KB 크기로 존재.
주의: 위 릴리스 태그/URL 형식은 설치된 `sqlite3` 버전에 따라 다를 수 있다. 404가 나면 https://pub.dev/packages/sqlite3 의 "Usage on the web" 문서에서 해당 버전의 wasm 다운로드 위치를 확인해 받는다.

- [ ] **Step 5: 빌드 동작 확인**

Run: `flutter analyze`
Expected: "No issues found!" (또는 기본 템플릿 경고만).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: scaffold flutter web project and add dependencies"
```

---

## Task 1: 카드 스케줄 상태 모델 (`srs/card_state.dart`)

**Files:**
- Create: `lib/srs/card_state.dart`
- Test: `test/srs/card_state_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/srs/card_state_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ankiyo/srs/card_state.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1, 9);

  test('CardState.create는 신규 카드 기본값을 갖는다', () {
    final s = CardState.create(now);
    expect(s.status, CardStatus.newCard);
    expect(s.due, now);
    expect(s.intervalDays, 0);
    expect(s.easeFactor, 2.5);
    expect(s.reps, 0);
    expect(s.lapses, 0);
    expect(s.learningStepIndex, 0);
  });

  test('copyWith는 새 객체를 반환하고 원본을 변경하지 않는다', () {
    final s = CardState.create(now);
    final s2 = s.copyWith(reps: 5, status: CardStatus.review);
    expect(s2.reps, 5);
    expect(s2.status, CardStatus.review);
    expect(s.reps, 0); // 원본 불변
    expect(s.status, CardStatus.newCard);
    expect(s2.easeFactor, 2.5); // 미지정 값 유지
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/srs/card_state_test.dart`
Expected: FAIL — `card_state.dart` / `CardState` 없음.

- [ ] **Step 3: 최소 구현**

`lib/srs/card_state.dart`:
```dart
enum CardStatus { newCard, learning, review, relearning }

enum Rating { again, hard, good, easy }

class CardState {
  final CardStatus status;
  final DateTime due;
  final double intervalDays;
  final double easeFactor;
  final int reps;
  final int lapses;
  final int learningStepIndex;

  const CardState({
    required this.status,
    required this.due,
    required this.intervalDays,
    required this.easeFactor,
    required this.reps,
    required this.lapses,
    required this.learningStepIndex,
  });

  factory CardState.create(DateTime now) => CardState(
        status: CardStatus.newCard,
        due: now,
        intervalDays: 0,
        easeFactor: 2.5,
        reps: 0,
        lapses: 0,
        learningStepIndex: 0,
      );

  CardState copyWith({
    CardStatus? status,
    DateTime? due,
    double? intervalDays,
    double? easeFactor,
    int? reps,
    int? lapses,
    int? learningStepIndex,
  }) =>
      CardState(
        status: status ?? this.status,
        due: due ?? this.due,
        intervalDays: intervalDays ?? this.intervalDays,
        easeFactor: easeFactor ?? this.easeFactor,
        reps: reps ?? this.reps,
        lapses: lapses ?? this.lapses,
        learningStepIndex: learningStepIndex ?? this.learningStepIndex,
      );
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/srs/card_state_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/srs/card_state.dart test/srs/card_state_test.dart
git commit -m "feat(srs): add immutable CardState model"
```

---

## Task 2: SRS 스케줄러 (`srs/scheduler.dart`) — 핵심

**Files:**
- Create: `lib/srs/scheduler.dart`
- Test: `test/srs/scheduler_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/srs/scheduler_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ankiyo/srs/card_state.dart';
import 'package:ankiyo/srs/scheduler.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1, 9);
  const sched = Scheduler(); // 기본 config

  group('신규/학습 카드', () {
    test('Again은 학습 첫 스텝(1분 뒤)으로 보낸다', () {
      final s = CardState.create(now);
      final r = sched.review(s, Rating.again, now);
      expect(r.status, CardStatus.learning);
      expect(r.learningStepIndex, 0);
      expect(r.due, now.add(const Duration(minutes: 1)));
    });

    test('Good은 다음 학습 스텝(10분 뒤)으로 전진한다', () {
      final s = CardState.create(now); // stepIndex 0
      final r = sched.review(s, Rating.good, now);
      expect(r.status, CardStatus.learning);
      expect(r.learningStepIndex, 1);
      expect(r.due, now.add(const Duration(minutes: 10)));
    });

    test('마지막 스텝에서 Good이면 졸업(1일 간격)', () {
      final s = CardState.create(now).copyWith(
          status: CardStatus.learning, learningStepIndex: 1);
      final r = sched.review(s, Rating.good, now);
      expect(r.status, CardStatus.review);
      expect(r.intervalDays, 1);
      expect(r.due, now.add(const Duration(days: 1)));
      expect(r.reps, 1);
    });

    test('Easy는 즉시 졸업(4일 간격)', () {
      final s = CardState.create(now);
      final r = sched.review(s, Rating.easy, now);
      expect(r.status, CardStatus.review);
      expect(r.intervalDays, 4);
      expect(r.due, now.add(const Duration(days: 4)));
    });
  });

  group('복습 카드', () {
    CardState reviewCard({double ivl = 10, double ease = 2.5}) =>
        CardState.create(now).copyWith(
          status: CardStatus.review,
          intervalDays: ivl,
          easeFactor: ease,
          reps: 3,
        );

    test('Good은 간격 = 간격 × ease', () {
      final r = sched.review(reviewCard(ivl: 10, ease: 2.5), Rating.good, now);
      expect(r.intervalDays, closeTo(25, 0.001)); // 10 * 2.5
      expect(r.due, now.add(const Duration(days: 25)));
      expect(r.reps, 4);
    });

    test('Hard는 간격 × 1.2, ease 감소', () {
      final r = sched.review(reviewCard(ivl: 10, ease: 2.5), Rating.hard, now);
      expect(r.intervalDays, closeTo(12, 0.001)); // 10 * 1.2
      expect(r.easeFactor, closeTo(2.35, 0.001)); // 2.5 - 0.15
    });

    test('Easy는 간격 × ease × 1.3, ease 증가', () {
      final r = sched.review(reviewCard(ivl: 10, ease: 2.5), Rating.easy, now);
      expect(r.easeFactor, closeTo(2.65, 0.001)); // 2.5 + 0.15
      expect(r.intervalDays, closeTo(34.45, 0.001)); // 10 * 2.65 * 1.3
    });

    test('Again은 lapse 처리 후 relearning으로 보낸다', () {
      final r = sched.review(reviewCard(ivl: 10, ease: 2.5), Rating.again, now);
      expect(r.status, CardStatus.relearning);
      expect(r.lapses, 1);
      expect(r.easeFactor, closeTo(2.3, 0.001)); // 2.5 - 0.20
      expect(r.due, now.add(const Duration(minutes: 10))); // relearning step
      expect(r.intervalDays, 1); // lapseFactor 0 → max(1)
    });

    test('ease는 minEase(1.3) 아래로 내려가지 않는다', () {
      final r = sched.review(reviewCard(ease: 1.3), Rating.again, now);
      expect(r.easeFactor, 1.3);
    });

    test('간격은 최소 현재+1일 보장', () {
      final r = sched.review(reviewCard(ivl: 1, ease: 1.3), Rating.hard, now);
      expect(r.intervalDays, greaterThanOrEqualTo(2)); // 1*1.2=1.2 < 2 → 2
    });
  });

  group('relearning 카드', () {
    test('Good이면 review로 복귀(최소 1일)', () {
      final s = CardState.create(now).copyWith(
          status: CardStatus.relearning, intervalDays: 1, learningStepIndex: 0);
      final r = sched.review(s, Rating.good, now);
      expect(r.status, CardStatus.review);
      expect(r.intervalDays, greaterThanOrEqualTo(1));
    });

    test('Again이면 relearning 첫 스텝 유지', () {
      final s = CardState.create(now).copyWith(
          status: CardStatus.relearning, intervalDays: 1);
      final r = sched.review(s, Rating.again, now);
      expect(r.status, CardStatus.relearning);
      expect(r.learningStepIndex, 0);
    });
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/srs/scheduler_test.dart`
Expected: FAIL — `scheduler.dart` / `Scheduler` 없음.

- [ ] **Step 3: 최소 구현**

`lib/srs/scheduler.dart`:
```dart
import 'card_state.dart';

class SchedulerConfig {
  final List<Duration> learningSteps;
  final List<Duration> relearningSteps;
  final double minEase;
  final double easeAgainDelta;
  final double easeHardDelta;
  final double easeEasyDelta;
  final double hardMultiplier;
  final double easyBonus;
  final int graduatingIntervalDays;
  final int easyIntervalDays;
  final double lapseNewIntervalFactor;

  const SchedulerConfig({
    this.learningSteps = const [Duration(minutes: 1), Duration(minutes: 10)],
    this.relearningSteps = const [Duration(minutes: 10)],
    this.minEase = 1.3,
    this.easeAgainDelta = -0.20,
    this.easeHardDelta = -0.15,
    this.easeEasyDelta = 0.15,
    this.hardMultiplier = 1.2,
    this.easyBonus = 1.3,
    this.graduatingIntervalDays = 1,
    this.easyIntervalDays = 4,
    this.lapseNewIntervalFactor = 0.0,
  });
}

class Scheduler {
  final SchedulerConfig config;
  const Scheduler([this.config = const SchedulerConfig()]);

  CardState review(CardState s, Rating rating, DateTime now) {
    switch (s.status) {
      case CardStatus.newCard:
      case CardStatus.learning:
        return _learning(s, rating, now);
      case CardStatus.relearning:
        return _relearning(s, rating, now);
      case CardStatus.review:
        return _review(s, rating, now);
    }
  }

  CardState _learning(CardState s, Rating rating, DateTime now) {
    final steps = config.learningSteps;
    switch (rating) {
      case Rating.again:
        return s.copyWith(
            status: CardStatus.learning,
            learningStepIndex: 0,
            intervalDays: 0,
            due: now.add(steps.first));
      case Rating.hard:
        final idx = s.learningStepIndex.clamp(0, steps.length - 1);
        return s.copyWith(
            status: CardStatus.learning,
            learningStepIndex: idx,
            intervalDays: 0,
            due: now.add(steps[idx]));
      case Rating.good:
        final nextIdx = s.learningStepIndex + 1;
        if (nextIdx >= steps.length) {
          return s.copyWith(
              status: CardStatus.review,
              intervalDays: config.graduatingIntervalDays.toDouble(),
              learningStepIndex: 0,
              reps: s.reps + 1,
              due: now.add(Duration(days: config.graduatingIntervalDays)));
        }
        return s.copyWith(
            status: CardStatus.learning,
            learningStepIndex: nextIdx,
            intervalDays: 0,
            due: now.add(steps[nextIdx]));
      case Rating.easy:
        return s.copyWith(
            status: CardStatus.review,
            intervalDays: config.easyIntervalDays.toDouble(),
            learningStepIndex: 0,
            reps: s.reps + 1,
            due: now.add(Duration(days: config.easyIntervalDays)));
    }
  }

  CardState _relearning(CardState s, Rating rating, DateTime now) {
    final steps = config.relearningSteps;
    switch (rating) {
      case Rating.again:
        return s.copyWith(learningStepIndex: 0, due: now.add(steps.first));
      case Rating.hard:
        final idx = s.learningStepIndex.clamp(0, steps.length - 1);
        return s.copyWith(due: now.add(steps[idx]));
      case Rating.good:
        final nextIdx = s.learningStepIndex + 1;
        if (nextIdx >= steps.length) {
          final ivl = s.intervalDays < 1 ? 1.0 : s.intervalDays;
          return s.copyWith(
              status: CardStatus.review,
              intervalDays: ivl,
              learningStepIndex: 0,
              due: now.add(Duration(days: ivl.round())));
        }
        return s.copyWith(
            learningStepIndex: nextIdx, due: now.add(steps[nextIdx]));
      case Rating.easy:
        final ivl = (s.intervalDays < 1 ? 1.0 : s.intervalDays) + 1;
        return s.copyWith(
            status: CardStatus.review,
            intervalDays: ivl,
            learningStepIndex: 0,
            due: now.add(Duration(days: ivl.round())));
    }
  }

  CardState _review(CardState s, Rating rating, DateTime now) {
    switch (rating) {
      case Rating.again:
        final newEase = _clampEase(s.easeFactor + config.easeAgainDelta);
        final lapsedIvl = _atLeast(
            s.intervalDays * config.lapseNewIntervalFactor, 1);
        return s.copyWith(
            status: CardStatus.relearning,
            easeFactor: newEase,
            lapses: s.lapses + 1,
            learningStepIndex: 0,
            intervalDays: lapsedIvl,
            due: now.add(config.relearningSteps.first));
      case Rating.hard:
        final newEase = _clampEase(s.easeFactor + config.easeHardDelta);
        final ivl = _nextIvl(s.intervalDays * config.hardMultiplier, s.intervalDays);
        return s.copyWith(
            easeFactor: newEase,
            intervalDays: ivl,
            reps: s.reps + 1,
            due: now.add(Duration(days: ivl.round())));
      case Rating.good:
        final ivl = _nextIvl(s.intervalDays * s.easeFactor, s.intervalDays);
        return s.copyWith(
            intervalDays: ivl,
            reps: s.reps + 1,
            due: now.add(Duration(days: ivl.round())));
      case Rating.easy:
        final newEase = s.easeFactor + config.easeEasyDelta;
        final ivl = _nextIvl(
            s.intervalDays * newEase * config.easyBonus, s.intervalDays);
        return s.copyWith(
            easeFactor: newEase,
            intervalDays: ivl,
            reps: s.reps + 1,
            due: now.add(Duration(days: ivl.round())));
    }
  }

  double _clampEase(double e) => e < config.minEase ? config.minEase : e;
  double _atLeast(double v, double min) => v < min ? min : v;
  double _nextIvl(double proposed, double current) =>
      proposed < current + 1 ? current + 1 : proposed;
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/srs/scheduler_test.dart`
Expected: PASS (전체 그룹 통과).

- [ ] **Step 5: Commit**

```bash
git add lib/srs/scheduler.dart test/srs/scheduler_test.dart
git commit -m "feat(srs): add SM-2 variant scheduler"
```

---

## Task 3: 노트타입/노트 모델 (`apkg/anki_model.dart`, `apkg/anki_note.dart`)

**Files:**
- Create: `lib/apkg/anki_model.dart`
- Create: `lib/apkg/anki_note.dart`
- Test: `test/apkg/anki_model_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/apkg/anki_model_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ankiyo/apkg/anki_model.dart';
import 'package:ankiyo/apkg/anki_note.dart';

void main() {
  test('AnkiModel.fromJson은 필드/템플릿/타입을 파싱한다', () {
    final json = {
      'id': 1,
      'name': 'Basic',
      'type': 0,
      'css': '.card{}',
      'flds': [
        {'name': 'Front', 'ord': 0},
        {'name': 'Back', 'ord': 1},
      ],
      'tmpls': [
        {'name': 'Card 1', 'ord': 0, 'qfmt': '{{Front}}', 'afmt': '{{FrontSide}}<hr>{{Back}}'},
      ],
    };
    final m = AnkiModel.fromJson(json);
    expect(m.id, 1);
    expect(m.type, 0);
    expect(m.fields.map((f) => f.name), ['Front', 'Back']);
    expect(m.templates.first.qfmt, '{{Front}}');
  });

  test('AnkiNote.fieldMap은 \\x1f로 분리해 필드명에 매핑한다', () {
    final m = AnkiModel.fromJson({
      'id': 1, 'name': 'Basic', 'type': 0, 'css': '',
      'flds': [
        {'name': 'Front', 'ord': 0},
        {'name': 'Back', 'ord': 1},
      ],
      'tmpls': [],
    });
    final note = AnkiNote(id: 5, mid: 1, fieldsRaw: 'hello\x1fworld');
    final map = note.fieldMap(m);
    expect(map, {'Front': 'hello', 'Back': 'world'});
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/apkg/anki_model_test.dart`
Expected: FAIL — 모델 클래스 없음.

- [ ] **Step 3: 최소 구현**

`lib/apkg/anki_model.dart`:
```dart
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
```

`lib/apkg/anki_note.dart`:
```dart
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
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/apkg/anki_model_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/apkg/anki_model.dart lib/apkg/anki_note.dart test/apkg/anki_model_test.dart
git commit -m "feat(apkg): add Anki model and note parsing"
```

---

## Task 4: 카드 빌더 — 템플릿 + cloze (`apkg/card_builder.dart`)

**Files:**
- Create: `lib/apkg/card_builder.dart`
- Test: `test/apkg/card_builder_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/apkg/card_builder_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ankiyo/apkg/anki_model.dart';
import 'package:ankiyo/apkg/anki_note.dart';
import 'package:ankiyo/apkg/card_builder.dart';

void main() {
  final builder = const CardBuilder();

  group('표준 노트', () {
    final basic = AnkiModel.fromJson({
      'id': 1, 'name': 'Basic', 'type': 0, 'css': '',
      'flds': [
        {'name': 'Front', 'ord': 0},
        {'name': 'Back', 'ord': 1},
      ],
      'tmpls': [
        {'name': 'Card 1', 'ord': 0, 'qfmt': '{{Front}}', 'afmt': '{{FrontSide}}<hr>{{Back}}'},
      ],
    });

    test('필드 치환과 FrontSide를 처리한다', () {
      final note = AnkiNote(id: 1, mid: 1, fieldsRaw: '안녕\x1fhello');
      final card = builder.build(note: note, model: basic, ord: 0);
      expect(card.frontHtml, '안녕');
      expect(card.backHtml, '안녕<hr>hello');
      expect(card.isCloze, false);
    });

    test('조건부 섹션을 처리한다 (#있을때 / ^없을때)', () {
      final model = AnkiModel.fromJson({
        'id': 2, 'name': 'C', 'type': 0, 'css': '',
        'flds': [
          {'name': 'Front', 'ord': 0},
          {'name': 'Hint', 'ord': 1},
        ],
        'tmpls': [
          {'name': 'Card 1', 'ord': 0,
           'qfmt': '{{Front}}{{#Hint}} ({{Hint}}){{/Hint}}', 'afmt': ''},
        ],
      });
      final withHint = builder.build(
          note: AnkiNote(id: 1, mid: 2, fieldsRaw: 'Q\x1f힌트'), model: model, ord: 0);
      expect(withHint.frontHtml, 'Q (힌트)');
      final noHint = builder.build(
          note: AnkiNote(id: 2, mid: 2, fieldsRaw: 'Q\x1f'), model: model, ord: 0);
      expect(noHint.frontHtml, 'Q');
    });
  });

  group('cloze 노트', () {
    final cloze = AnkiModel.fromJson({
      'id': 10, 'name': 'Cloze', 'type': 1, 'css': '',
      'flds': [
        {'name': 'Text', 'ord': 0},
        {'name': 'Extra', 'ord': 1},
      ],
      'tmpls': [
        {'name': 'Cloze', 'ord': 0,
         'qfmt': '{{cloze:Text}}', 'afmt': '{{cloze:Text}}<br>{{Extra}}'},
      ],
    });

    test('앞면은 활성 클로즈를 가리고 다른 클로즈는 노출한다', () {
      final note = AnkiNote(
          id: 1, mid: 10,
          fieldsRaw: '{{c1::파리}}는 {{c2::프랑스}}의 수도\x1f메모');
      final card1 = builder.build(note: note, model: cloze, ord: 0); // c1
      expect(card1.frontHtml, '[...]는 프랑스의 수도');
      expect(card1.backHtml, contains('파리'));
      expect(card1.backHtml, contains('class="cloze"'));
      expect(card1.isCloze, true);
    });

    test('힌트가 있으면 [힌트] 형태로 가린다', () {
      final note = AnkiNote(id: 2, mid: 10, fieldsRaw: '정답은 {{c1::42::숫자}}\x1f');
      final card = builder.build(note: note, model: cloze, ord: 0);
      expect(card.frontHtml, '정답은 [숫자]');
    });

    test('clozeNumbers는 노트의 distinct 클로즈 번호를 반환한다', () {
      final note = AnkiNote(
          id: 3, mid: 10, fieldsRaw: '{{c1::a}} {{c2::b}} {{c1::c}}\x1f');
      expect(builder.clozeNumbers(note, cloze), [1, 2]);
    });
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/apkg/card_builder_test.dart`
Expected: FAIL — `CardBuilder` 없음.

- [ ] **Step 3: 최소 구현**

`lib/apkg/card_builder.dart`:
```dart
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
          : const AnkiTemplate(name: '', ord: 0, qfmt: '{{cloze:Text}}', afmt: '{{cloze:Text}}');
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
    // {{cloze:Field}} 토큰을 클로즈 처리한 값으로 치환, 그 외 필드는 일반 치환
    var out = template.replaceAllMapped(
        RegExp(r'\{\{cloze:(\w+)\}\}'), (m) {
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
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/apkg/card_builder_test.dart`
Expected: PASS (전체 통과).

- [ ] **Step 5: Commit**

```bash
git add lib/apkg/card_builder.dart test/apkg/card_builder_test.dart
git commit -m "feat(apkg): add template + cloze card builder"
```

---

## Task 5: APKG 리더 (zip 해제) (`apkg/apkg_reader.dart`)

**Files:**
- Create: `lib/apkg/apkg_reader.dart`
- Test: `test/apkg/apkg_reader_test.dart`
- Test fixture: `test/fixtures/sample.apkg` (생성)

- [ ] **Step 1: 테스트 픽스처(.apkg) 생성**

작은 SQLite 컬렉션을 담은 구형 `.apkg`를 만들어 테스트에 쓴다. 아래 스크립트를 실행한다.

Run:
```bash
mkdir -p test/fixtures
python3 - <<'PY'
import sqlite3, zipfile, json, os, time
os.makedirs('test/fixtures', exist_ok=True)
dbp = 'test/fixtures/collection.anki21'
if os.path.exists(dbp): os.remove(dbp)
con = sqlite3.connect(dbp); cur = con.cursor()
cur.executescript('''
CREATE TABLE col (id integer primary key, crt integer, mod integer, scm integer,
  ver integer, dty integer, usn integer, ls integer, conf text, models text,
  decks text, dconf text, tags text);
CREATE TABLE notes (id integer primary key, guid text, mid integer, mod integer,
  usn integer, tags text, flds text, sfld text, csum integer, flags integer, data text);
CREATE TABLE cards (id integer primary key, nid integer, did integer, ord integer,
  mod integer, usn integer, type integer, queue integer, due integer, ivl integer,
  factor integer, reps integer, lapses integer, left integer, odue integer,
  odid integer, flags integer, data text);
''')
models = {"1":{"id":1,"name":"Basic","type":0,"css":".card{}",
  "flds":[{"name":"Front","ord":0},{"name":"Back","ord":1}],
  "tmpls":[{"name":"Card 1","ord":0,"qfmt":"{{Front}}","afmt":"{{FrontSide}}<hr>{{Back}}"}]}}
decks = {"1":{"id":1,"name":"Default"},"2":{"id":2,"name":"Korean::Capitals"}}
cur.execute("INSERT INTO col VALUES (1,?,?,?,11,0,0,0,'{}',?,?,'{}','{}')",
  (int(time.time()),int(time.time()*1000),int(time.time()*1000),
   json.dumps(models), json.dumps(decks)))
cur.execute("INSERT INTO notes VALUES (100,'g1',1,0,0,'','Bonjour\x1fHello','Bonjour',0,0,'')")
cur.execute("INSERT INTO notes VALUES (101,'g2',1,0,0,'','Merci\x1fThanks','Merci',0,0,'')")
cur.execute("INSERT INTO cards VALUES (200,100,2,0,0,0,0,0,0,0,2500,0,0,0,0,0,0,'')")
cur.execute("INSERT INTO cards VALUES (201,101,2,0,0,0,0,0,0,0,2500,0,0,0,0,0,0,'')")
con.commit(); con.close()
with zipfile.ZipFile('test/fixtures/sample.apkg','w',zipfile.ZIP_DEFLATED) as z:
    z.write(dbp, 'collection.anki21')
    z.writestr('media', '{}')
os.remove(dbp)
print('wrote test/fixtures/sample.apkg')
PY
ls -la test/fixtures/sample.apkg
```
Expected: `test/fixtures/sample.apkg` 생성됨.

- [ ] **Step 2: 실패하는 테스트 작성**

`test/apkg/apkg_reader_test.dart`:
```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ankiyo/apkg/apkg_reader.dart';

void main() {
  test('구형 .apkg에서 collection.anki21 바이트를 추출한다', () {
    final bytes = File('test/fixtures/sample.apkg').readAsBytesSync();
    final db = ApkgReader.extractCollection(bytes);
    // SQLite 파일 매직 헤더
    expect(String.fromCharCodes(db.sublist(0, 15)), 'SQLite format 3');
  });

  test('컬렉션이 없는 zip은 UnsupportedApkgException', () {
    // collection 항목이 없는 더미 zip은 예외 발생
    expect(
      () => ApkgReader.extractCollection(_emptyZip()),
      throwsA(isA<UnsupportedApkgException>()),
    );
  });
}

// 빈 zip 바이트 (PK 헤더만 있는 최소 zip)
List<int> _emptyZip() => [0x50, 0x4b, 0x05, 0x06, ...List.filled(18, 0)];
```

- [ ] **Step 3: 테스트 실패 확인**

Run: `flutter test test/apkg/apkg_reader_test.dart`
Expected: FAIL — `ApkgReader` 없음.

- [ ] **Step 4: 최소 구현**

`lib/apkg/apkg_reader.dart`:
```dart
import 'dart:typed_data';
import 'package:archive/archive.dart';

class UnsupportedApkgException implements Exception {
  final String message;
  const UnsupportedApkgException(this.message);
  @override
  String toString() => 'UnsupportedApkgException: $message';
}

class ApkgReader {
  /// .apkg(zip) 바이트에서 SQLite 컬렉션 바이트를 추출한다.
  /// 구형 포맷(collection.anki21 / collection.anki2)만 지원.
  static Uint8List extractCollection(List<int> apkgBytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(apkgBytes);
    } catch (e) {
      throw const UnsupportedApkgException('zip을 읽을 수 없습니다. .apkg 파일이 맞나요?');
    }

    // 신형(zstd) 포맷 감지: collection.anki21b가 있으면 미지원
    if (archive.findFile('collection.anki21b') != null) {
      throw const UnsupportedApkgException(
          '신형(압축) .apkg는 아직 지원되지 않습니다. Anki에서 "이전 버전 지원"을 켜고 다시 내보내 주세요.');
    }

    final file = archive.findFile('collection.anki21') ??
        archive.findFile('collection.anki2');
    if (file == null) {
      throw const UnsupportedApkgException(
          '컬렉션 데이터를 찾지 못했습니다. 올바른 Anki 덱 파일이 아닙니다.');
    }
    return Uint8List.fromList(file.content as List<int>);
  }
}
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `flutter test test/apkg/apkg_reader_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/apkg/apkg_reader.dart test/apkg/apkg_reader_test.dart test/fixtures/sample.apkg
git commit -m "feat(apkg): extract collection db from apkg zip"
```

---

## Task 6: Anki DB 읽기 (`apkg/anki_db.dart`)

**Files:**
- Create: `lib/apkg/anki_db.dart`
- Test: `test/apkg/anki_db_test.dart` (네이티브 sqlite3로 검증)

> 참고: 이 태스크의 SQL 쿼리는 확정적이다. 단, **웹에서 바이트로 sqlite3를 여는 wasm 배선**은 `sqlite3` 패키지 버전마다 API가 다르므로, 웹 경로 구현 전 https://pub.dev/packages/sqlite3 의 "Using this package on the web" 문서로 정확한 호출을 확인한다. 테스트는 네이티브(VM) sqlite3로 한다.

- [ ] **Step 1: 실패하는 테스트 작성**

`test/apkg/anki_db_test.dart`:
```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:ankiyo/apkg/apkg_reader.dart';
import 'package:ankiyo/apkg/anki_db.dart';

void main() {
  test('샘플 컬렉션에서 덱별 카드 앞/뒤를 추출한다', () {
    final apkg = File('test/fixtures/sample.apkg').readAsBytesSync();
    final dbBytes = ApkgReader.extractCollection(apkg);

    // 네이티브: 바이트를 임시 파일로 써서 연다
    final tmp = File('${Directory.systemTemp.path}/anki_test.db');
    tmp.writeAsBytesSync(dbBytes);
    final db = sqlite3.open(tmp.path);

    final reader = AnkiCollectionReader(db);
    final decks = reader.readDecks();
    expect(decks.any((d) => d.name == 'Korean::Capitals' && d.ankiId == 2), true);

    final cards = reader.readCards();
    expect(cards.length, 2);
    final bonjour = cards.firstWhere((c) => c.frontHtml.contains('Bonjour'));
    expect(bonjour.backHtml, contains('Hello'));
    expect(bonjour.deckAnkiId, 2);

    db.dispose();
    tmp.deleteSync();
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/apkg/anki_db_test.dart`
Expected: FAIL — `AnkiCollectionReader` 없음.

- [ ] **Step 3: 최소 구현**

`lib/apkg/anki_db.dart`:
```dart
import 'dart:convert';
import 'package:sqlite3/common.dart';
import 'anki_model.dart';
import 'anki_note.dart';
import 'card_builder.dart';

class ParsedDeck {
  final int ankiId;
  final String name;
  const ParsedDeck({required this.ankiId, required this.name});
}

class ParsedCard {
  final int deckAnkiId;
  final String frontHtml;
  final String backHtml;
  final bool isCloze;
  const ParsedCard({
    required this.deckAnkiId,
    required this.frontHtml,
    required this.backHtml,
    required this.isCloze,
  });
}

/// 이미 열린 sqlite [CommonDatabase]에서 Anki 컬렉션을 읽는다.
/// (DB 오픈은 플랫폼별 호출자가 담당 — 웹: wasm, 네이티브: 파일)
class AnkiCollectionReader {
  final CommonDatabase db;
  final CardBuilder _builder;

  AnkiCollectionReader(this.db, {CardBuilder builder = const CardBuilder()})
      : _builder = builder;

  Map<String, dynamic> _col() {
    final row = db.select('SELECT models, decks FROM col LIMIT 1').first;
    return {
      'models': jsonDecode(row['models'] as String) as Map<String, dynamic>,
      'decks': jsonDecode(row['decks'] as String) as Map<String, dynamic>,
    };
  }

  List<ParsedDeck> readDecks() {
    final decks = _col()['decks'] as Map<String, dynamic>;
    return decks.entries.map((e) {
      final v = Map<String, dynamic>.from(e.value as Map);
      return ParsedDeck(ankiId: int.parse(e.key), name: v['name'] as String? ?? '?');
    }).toList();
  }

  List<ParsedCard> readCards() {
    final col = _col();
    final modelsJson = col['models'] as Map<String, dynamic>;
    final models = <int, AnkiModel>{};
    for (final entry in modelsJson.entries) {
      final m = AnkiModel.fromJson(Map<String, dynamic>.from(entry.value as Map));
      models[m.id] = m;
    }

    // 노트 캐시
    final notes = <int, AnkiNote>{};
    for (final r in db.select('SELECT id, mid, flds FROM notes')) {
      notes[r['id'] as int] = AnkiNote(
        id: r['id'] as int,
        mid: r['mid'] as int,
        fieldsRaw: r['flds'] as String,
      );
    }

    final result = <ParsedCard>[];
    for (final r in db.select('SELECT nid, did, ord FROM cards')) {
      final note = notes[r['nid'] as int];
      if (note == null) continue;
      final model = models[note.mid];
      if (model == null) continue; // 깨진 노트 → 건너뜀
      try {
        final built = _builder.build(note: note, model: model, ord: r['ord'] as int);
        result.add(ParsedCard(
          deckAnkiId: r['did'] as int,
          frontHtml: built.frontHtml,
          backHtml: built.backHtml,
          isCloze: built.isCloze,
        ));
      } catch (_) {
        // 렌더 실패 카드는 건너뛰고 계속
        continue;
      }
    }
    return result;
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/apkg/anki_db_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add lib/apkg/anki_db.dart test/apkg/anki_db_test.dart
git commit -m "feat(apkg): read decks and cards from anki sqlite collection"
```

---

## Task 7: 저장 모델 & sembast 저장소 (`storage/`)

**Files:**
- Create: `lib/storage/models.dart`
- Create: `lib/storage/db.dart`
- Create: `lib/storage/deck_repository.dart`
- Test: `test/storage/deck_repository_test.dart`

- [ ] **Step 1: 저장 모델 작성 (테스트 불필요한 직렬화 모델)**

`lib/storage/models.dart`:
```dart
import '../srs/card_state.dart';

class Deck {
  final String id;
  final String name;
  final DateTime importedAt;
  const Deck({required this.id, required this.name, required this.importedAt});

  Map<String, Object?> toMap() =>
      {'id': id, 'name': name, 'importedAt': importedAt.toIso8601String()};

  factory Deck.fromMap(Map<String, Object?> m) => Deck(
        id: m['id'] as String,
        name: m['name'] as String,
        importedAt: DateTime.parse(m['importedAt'] as String),
      );
}

class StudyCard {
  final String id;
  final String deckId;
  final String frontHtml;
  final String backHtml;
  final bool isCloze;
  final CardState state;

  const StudyCard({
    required this.id,
    required this.deckId,
    required this.frontHtml,
    required this.backHtml,
    required this.isCloze,
    required this.state,
  });

  StudyCard withState(CardState s) => StudyCard(
        id: id,
        deckId: deckId,
        frontHtml: frontHtml,
        backHtml: backHtml,
        isCloze: isCloze,
        state: s,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'deckId': deckId,
        'frontHtml': frontHtml,
        'backHtml': backHtml,
        'isCloze': isCloze,
        'status': state.status.name,
        'due': state.due.toIso8601String(),
        'intervalDays': state.intervalDays,
        'easeFactor': state.easeFactor,
        'reps': state.reps,
        'lapses': state.lapses,
        'learningStepIndex': state.learningStepIndex,
      };

  factory StudyCard.fromMap(Map<String, Object?> m) => StudyCard(
        id: m['id'] as String,
        deckId: m['deckId'] as String,
        frontHtml: m['frontHtml'] as String,
        backHtml: m['backHtml'] as String,
        isCloze: m['isCloze'] as bool,
        state: CardState(
          status: CardStatus.values.byName(m['status'] as String),
          due: DateTime.parse(m['due'] as String),
          intervalDays: (m['intervalDays'] as num).toDouble(),
          easeFactor: (m['easeFactor'] as num).toDouble(),
          reps: (m['reps'] as num).toInt(),
          lapses: (m['lapses'] as num).toInt(),
          learningStepIndex: (m['learningStepIndex'] as num).toInt(),
        ),
      );
}
```

- [ ] **Step 2: DB 오픈 헬퍼 작성**

`lib/storage/db.dart`:
```dart
import 'package:sembast/sembast.dart';
import 'package:sembast_web/sembast_web.dart';

/// 웹: IndexedDB. (네이티브 포팅 시 sembast_io로 분기 추가)
Future<Database> openAppDatabase() async {
  final factory = databaseFactoryWeb;
  return factory.openDatabase('ankiyo.db');
}
```

- [ ] **Step 3: 실패하는 테스트 작성 (인메모리 sembast)**

`test/storage/deck_repository_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:ankiyo/srs/card_state.dart';
import 'package:ankiyo/storage/models.dart';
import 'package:ankiyo/storage/deck_repository.dart';

void main() {
  late DeckRepository repo;

  setUp(() async {
    final db = await databaseFactoryMemory.openDatabase('test.db');
    repo = DeckRepository(db);
  });

  test('덱과 카드를 저장하고 다시 읽는다', () async {
    final now = DateTime.utc(2026, 1, 1);
    final deck = Deck(id: 'd1', name: 'Korean', importedAt: now);
    final cards = [
      StudyCard(id: 'c1', deckId: 'd1', frontHtml: 'A', backHtml: 'B',
          isCloze: false, state: CardState.create(now)),
      StudyCard(id: 'c2', deckId: 'd1', frontHtml: 'C', backHtml: 'D',
          isCloze: false, state: CardState.create(now)),
    ];
    await repo.saveDeck(deck, cards);

    final decks = await repo.getDecks();
    expect(decks.map((d) => d.name), ['Korean']);

    final loaded = await repo.getCards('d1');
    expect(loaded.length, 2);
  });

  test('카드 상태 갱신이 반영된다', () async {
    final now = DateTime.utc(2026, 1, 1);
    final card = StudyCard(id: 'c1', deckId: 'd1', frontHtml: 'A', backHtml: 'B',
        isCloze: false, state: CardState.create(now));
    await repo.saveDeck(
        Deck(id: 'd1', name: 'D', importedAt: now), [card]);

    await repo.updateCard(card.withState(card.state.copyWith(reps: 9)));
    final loaded = await repo.getCards('d1');
    expect(loaded.first.state.reps, 9);
  });

  test('덱 삭제 시 카드도 삭제된다', () async {
    final now = DateTime.utc(2026, 1, 1);
    await repo.saveDeck(Deck(id: 'd1', name: 'D', importedAt: now), [
      StudyCard(id: 'c1', deckId: 'd1', frontHtml: 'A', backHtml: 'B',
          isCloze: false, state: CardState.create(now)),
    ]);
    await repo.deleteDeck('d1');
    expect(await repo.getDecks(), isEmpty);
    expect(await repo.getCards('d1'), isEmpty);
  });
}
```

- [ ] **Step 4: 테스트 실패 확인**

Run: `flutter test test/storage/deck_repository_test.dart`
Expected: FAIL — `DeckRepository` 없음.

- [ ] **Step 5: 최소 구현**

`lib/storage/deck_repository.dart`:
```dart
import 'package:sembast/sembast.dart';
import 'models.dart';

class DeckRepository {
  final Database _db;
  final _decks = stringMapStoreFactory.store('decks');
  final _cards = stringMapStoreFactory.store('cards');

  DeckRepository(this._db);

  Future<void> saveDeck(Deck deck, List<StudyCard> cards) async {
    await _db.transaction((txn) async {
      await _decks.record(deck.id).put(txn, deck.toMap());
      for (final c in cards) {
        await _cards.record(c.id).put(txn, c.toMap());
      }
    });
  }

  Future<List<Deck>> getDecks() async {
    final records = await _decks.find(_db,
        finder: Finder(sortOrders: [SortOrder('importedAt')]));
    return records.map((r) => Deck.fromMap(r.value)).toList();
  }

  Future<List<StudyCard>> getCards(String deckId) async {
    final records = await _cards.find(_db,
        finder: Finder(filter: Filter.equals('deckId', deckId)));
    return records.map((r) => StudyCard.fromMap(r.value)).toList();
  }

  Future<void> updateCard(StudyCard card) async {
    await _cards.record(card.id).put(_db, card.toMap());
  }

  Future<void> deleteDeck(String deckId) async {
    await _db.transaction((txn) async {
      await _decks.record(deckId).delete(txn);
      await _cards.delete(txn,
          finder: Finder(filter: Filter.equals('deckId', deckId)));
    });
  }
}
```

- [ ] **Step 6: 테스트 통과 확인**

Run: `flutter test test/storage/deck_repository_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 7: Commit**

```bash
git add lib/storage/ test/storage/
git commit -m "feat(storage): add sembast deck/card repository"
```

---

## Task 8: 복습 큐 (`study/review_queue.dart`)

**Files:**
- Create: `lib/study/review_queue.dart`
- Test: `test/study/review_queue_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/study/review_queue_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ankiyo/srs/card_state.dart';
import 'package:ankiyo/storage/models.dart';
import 'package:ankiyo/study/review_queue.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1, 9);

  StudyCard card(String id, CardStatus status, DateTime due) => StudyCard(
        id: id, deckId: 'd', frontHtml: id, backHtml: id, isCloze: false,
        state: CardState.create(now).copyWith(status: status, due: due),
      );

  test('만기된 학습/복습 카드만, 한도 내 신규 카드를 포함한다', () {
    final cards = [
      card('new1', CardStatus.newCard, now),
      card('new2', CardStatus.newCard, now),
      card('new3', CardStatus.newCard, now),
      card('due_review', CardStatus.review, now.subtract(const Duration(hours: 1))),
      card('future_review', CardStatus.review, now.add(const Duration(days: 3))),
      card('due_learn', CardStatus.learning, now.subtract(const Duration(minutes: 5))),
    ];
    final queue = buildReviewQueue(cards, now: now,
        newLimit: 2, reviewLimit: 100);
    final ids = queue.map((c) => c.id).toList();

    expect(ids, contains('due_review'));
    expect(ids, contains('due_learn'));
    expect(ids, isNot(contains('future_review')));
    // 신규는 2장까지만
    expect(ids.where((i) => i.startsWith('new')).length, 2);
  });

  test('학습/relearning 카드가 신규·복습보다 앞에 온다', () {
    final cards = [
      card('new1', CardStatus.newCard, now),
      card('review1', CardStatus.review, now.subtract(const Duration(hours: 1))),
      card('learn1', CardStatus.learning, now.subtract(const Duration(minutes: 5))),
    ];
    final queue = buildReviewQueue(cards, now: now, newLimit: 10, reviewLimit: 10);
    expect(queue.first.id, 'learn1');
  });

  test('큐가 비면 빈 리스트', () {
    final queue = buildReviewQueue([], now: now, newLimit: 10, reviewLimit: 10);
    expect(queue, isEmpty);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/study/review_queue_test.dart`
Expected: FAIL — `buildReviewQueue` 없음.

- [ ] **Step 3: 최소 구현**

`lib/study/review_queue.dart`:
```dart
import '../srs/card_state.dart';
import '../storage/models.dart';

/// 오늘 학습 큐: 만기된 학습/relearning → 만기된 복습 → 신규(한도 내) 순서.
List<StudyCard> buildReviewQueue(
  List<StudyCard> cards, {
  required DateTime now,
  required int newLimit,
  required int reviewLimit,
}) {
  bool due(StudyCard c) => !c.state.due.isAfter(now);

  final learning = cards
      .where((c) =>
          (c.state.status == CardStatus.learning ||
              c.state.status == CardStatus.relearning) &&
          due(c))
      .toList()
    ..sort((a, b) => a.state.due.compareTo(b.state.due));

  final reviews = cards
      .where((c) => c.state.status == CardStatus.review && due(c))
      .toList()
    ..sort((a, b) => a.state.due.compareTo(b.state.due));

  final news =
      cards.where((c) => c.state.status == CardStatus.newCard).toList();

  return [
    ...learning,
    ...reviews.take(reviewLimit),
    ...news.take(newLimit),
  ];
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/study/review_queue_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/study/review_queue.dart test/study/review_queue_test.dart
git commit -m "feat(study): add review queue builder"
```

---

## Task 9: Import 서비스 (`storage/import_service.dart`)

**Files:**
- Create: `lib/storage/import_service.dart`
- Test: `test/storage/import_service_test.dart`

`ImportService`는 `apkg/`의 파싱 결과(`ParsedDeck`/`ParsedCard`)를 저장 모델로 바꿔 저장한다. DB 오픈은 호출자가 주입하므로, 이 서비스는 "이미 추출된 ParsedCard 목록 → 저장"을 담당해 단위 테스트가 쉽다.

- [ ] **Step 1: 실패하는 테스트 작성**

`test/storage/import_service_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:ankiyo/apkg/anki_db.dart';
import 'package:ankiyo/storage/deck_repository.dart';
import 'package:ankiyo/storage/import_service.dart';

void main() {
  test('ParsedDeck/ParsedCard를 덱별로 저장한다', () async {
    final db = await databaseFactoryMemory.openDatabase('imp.db');
    final repo = DeckRepository(db);
    final service = ImportService(repo);

    final decks = [
      const ParsedDeck(ankiId: 2, name: 'Korean::Capitals'),
      const ParsedDeck(ankiId: 1, name: 'Default'),
    ];
    final cards = [
      const ParsedCard(deckAnkiId: 2, frontHtml: 'Bonjour', backHtml: 'Hello', isCloze: false),
      const ParsedCard(deckAnkiId: 2, frontHtml: 'Merci', backHtml: 'Thanks', isCloze: false),
    ];

    final saved = await service.importParsed(
        decks: decks, cards: cards, now: DateTime.utc(2026, 1, 1));

    // 카드가 0장인 덱(Default)은 저장하지 않는다
    expect(saved.length, 1);
    expect(saved.first.name, 'Korean::Capitals');

    final loaded = await repo.getCards(saved.first.id);
    expect(loaded.length, 2);
    // 신규 카드 상태로 시작
    expect(loaded.every((c) => c.state.reps == 0), true);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/storage/import_service_test.dart`
Expected: FAIL — `ImportService` 없음.

- [ ] **Step 3: 최소 구현**

`lib/storage/import_service.dart`:
```dart
import 'package:uuid/uuid.dart';
import '../apkg/anki_db.dart';
import '../srs/card_state.dart';
import 'deck_repository.dart';
import 'models.dart';

class ImportService {
  final DeckRepository _repo;
  final Uuid _uuid;
  ImportService(this._repo, {Uuid uuid = const Uuid()}) : _uuid = uuid;

  /// 파싱된 덱/카드를 저장한다. 카드가 있는 덱만 저장하고, 저장한 Deck 목록을 반환.
  Future<List<Deck>> importParsed({
    required List<ParsedDeck> decks,
    required List<ParsedCard> cards,
    required DateTime now,
  }) async {
    final byAnkiId = <int, List<ParsedCard>>{};
    for (final c in cards) {
      byAnkiId.putIfAbsent(c.deckAnkiId, () => []).add(c);
    }

    final saved = <Deck>[];
    for (final pd in decks) {
      final deckCards = byAnkiId[pd.ankiId];
      if (deckCards == null || deckCards.isEmpty) continue;

      final deck = Deck(id: _uuid.v4(), name: pd.name, importedAt: now);
      final studyCards = deckCards
          .map((pc) => StudyCard(
                id: _uuid.v4(),
                deckId: deck.id,
                frontHtml: pc.frontHtml,
                backHtml: pc.backHtml,
                isCloze: pc.isCloze,
                state: CardState.create(now),
              ))
          .toList();
      await _repo.saveDeck(deck, studyCards);
      saved.add(deck);
    }
    return saved;
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/storage/import_service_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add lib/storage/import_service.dart test/storage/import_service_test.dart
git commit -m "feat(storage): add import service mapping parsed cards to study cards"
```

---

## Task 10: 웹 sqlite 오픈 + 전체 import 파이프라인 (`apkg/web_collection_opener.dart`)

**Files:**
- Create: `lib/apkg/collection_opener.dart`
- Create: `lib/apkg/collection_opener_web.dart`

> 이 태스크는 웹 런타임 의존(브라우저 wasm)이라 위젯/통합 테스트(Task 13)에서 검증한다. 여기서는 빌드가 통과하고 import가 동작하는 코드를 작성한다.

- [ ] **Step 1: 인터페이스 작성**

`lib/apkg/collection_opener.dart`:
```dart
import 'dart:typed_data';
import 'package:sqlite3/common.dart';

/// 추출된 SQLite 바이트로부터 [CommonDatabase]를 연다.
/// 웹/네이티브 구현이 다르다 (현재는 웹 구현만 제공).
abstract class CollectionOpener {
  Future<CommonDatabase> open(Uint8List dbBytes);
}
```

- [ ] **Step 2: 웹 구현 작성**

`lib/apkg/collection_opener_web.dart`:
```dart
import 'dart:typed_data';
import 'package:sqlite3/common.dart';
import 'package:sqlite3/wasm.dart';
import 'collection_opener.dart';

/// 웹 전용: sqlite3.wasm을 로드하고 인메모리 VFS에 바이트를 써서 연다.
///
/// 주의: InMemoryFileSystem에 바이트를 주입하는 정확한 호출은 설치된
/// `sqlite3` 패키지 버전 문서를 따른다. (pub.dev/packages/sqlite3 → web)
class WebCollectionOpener implements CollectionOpener {
  WasmSqlite3? _sqlite3;

  @override
  Future<CommonDatabase> open(Uint8List dbBytes) async {
    final fs = InMemoryFileSystem();
    _sqlite3 ??= await WasmSqlite3.loadFromUrl(
      Uri.parse('sqlite3.wasm'),
      environment: SqliteEnvironment(fileSystem: fs),
    );
    const path = '/collection.db';
    // 인메모리 FS에 DB 바이트 주입 후 열기.
    // (메서드명이 버전에 따라 다르면 문서의 'write bytes to file' 예시로 교체)
    fs.xOpenFile(Sqlite3Filename(path), SqlFlag.SQLITE_OPEN_CREATE | SqlFlag.SQLITE_OPEN_READWRITE);
    fs.createFile(path);
    (fs.fileData[path] ??= <int>[]).addAll(dbBytes);
    return _sqlite3!.open(path);
  }
}
```

> 검증 필수: `flutter analyze` 통과 후, 위 FS 주입부가 설치 버전 API와 맞는지 확인한다. 맞지 않으면 문서의 권장 패턴(예: `fs.xWrite` 또는 `IndexedDbFileSystem`)으로 교체하되, 시그니처 `open(Uint8List) → Future<CommonDatabase>`는 유지한다.

- [ ] **Step 3: 빌드/정적분석 확인**

Run: `flutter analyze lib/apkg/collection_opener.dart lib/apkg/collection_opener_web.dart`
Expected: 에러 없음. (경고가 있으면 API를 문서대로 교정)

- [ ] **Step 4: Commit**

```bash
git add lib/apkg/collection_opener.dart lib/apkg/collection_opener_web.dart
git commit -m "feat(apkg): add web sqlite collection opener"
```

---

## Task 11: 상태관리 컨트롤러 (`ui/controllers/`)

**Files:**
- Create: `lib/ui/controllers/deck_list_controller.dart`
- Create: `lib/ui/controllers/review_controller.dart`
- Test: `test/ui/review_controller_test.dart`

- [ ] **Step 1: ReviewController 실패 테스트 작성**

`test/ui/review_controller_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:ankiyo/srs/card_state.dart';
import 'package:ankiyo/srs/scheduler.dart';
import 'package:ankiyo/storage/deck_repository.dart';
import 'package:ankiyo/storage/models.dart';
import 'package:ankiyo/ui/controllers/review_controller.dart';

void main() {
  test('평가하면 다음 카드로 진행하고 상태를 저장한다', () async {
    final now = DateTime.utc(2026, 1, 1, 9);
    final db = await databaseFactoryMemory.openDatabase('rc.db');
    final repo = DeckRepository(db);
    final cards = [
      StudyCard(id: 'c1', deckId: 'd1', frontHtml: 'A', backHtml: 'B',
          isCloze: false, state: CardState.create(now)),
      StudyCard(id: 'c2', deckId: 'd1', frontHtml: 'C', backHtml: 'D',
          isCloze: false, state: CardState.create(now)),
    ];
    await repo.saveDeck(Deck(id: 'd1', name: 'D', importedAt: now), cards);

    final controller = ReviewController(
      repo: repo,
      scheduler: const Scheduler(),
      deckId: 'd1',
      newLimit: 20,
      reviewLimit: 200,
      clock: () => now,
    );
    await controller.load();
    expect(controller.remaining, 2);
    expect(controller.showingBack, false);

    controller.reveal();
    expect(controller.showingBack, true);

    await controller.rate(Rating.good);
    expect(controller.remaining, 1); // 다음 카드로

    // 저장 반영 확인
    final saved = await repo.getCards('d1');
    expect(saved.any((c) => c.state.reps > 0 || c.state.status != CardStatus.newCard), true);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/ui/review_controller_test.dart`
Expected: FAIL — `ReviewController` 없음.

- [ ] **Step 3: ReviewController 구현**

`lib/ui/controllers/review_controller.dart`:
```dart
import 'package:flutter/foundation.dart';
import '../../srs/card_state.dart';
import '../../srs/scheduler.dart';
import '../../storage/deck_repository.dart';
import '../../storage/models.dart';
import '../../study/review_queue.dart';

class ReviewController extends ChangeNotifier {
  final DeckRepository repo;
  final Scheduler scheduler;
  final String deckId;
  final int newLimit;
  final int reviewLimit;
  final DateTime Function() clock;

  ReviewController({
    required this.repo,
    required this.scheduler,
    required this.deckId,
    required this.newLimit,
    required this.reviewLimit,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  List<StudyCard> _queue = [];
  int _index = 0;
  bool _showingBack = false;
  bool _loading = true;

  bool get loading => _loading;
  bool get showingBack => _showingBack;
  bool get isDone => _index >= _queue.length;
  int get remaining => _queue.length - _index;
  StudyCard? get current => isDone ? null : _queue[_index];

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    final cards = await repo.getCards(deckId);
    _queue = buildReviewQueue(cards,
        now: clock(), newLimit: newLimit, reviewLimit: reviewLimit);
    _index = 0;
    _showingBack = false;
    _loading = false;
    notifyListeners();
  }

  void reveal() {
    _showingBack = true;
    notifyListeners();
  }

  /// 등급 평가 후 다음 카드로. 미리보기용 다음 상태도 계산 가능.
  Future<void> rate(Rating rating) async {
    final card = current;
    if (card == null) return;
    final newState = scheduler.review(card.state, rating, clock());
    await repo.updateCard(card.withState(newState));
    _index += 1;
    _showingBack = false;
    notifyListeners();
  }

  /// 버튼 라벨용: 이 등급을 주면 다음 복습이 언제인지 사람이 읽는 문자열.
  String previewLabel(Rating rating) {
    final card = current;
    if (card == null) return '';
    final s = scheduler.review(card.state, rating, clock());
    final d = s.due.difference(clock());
    if (d.inDays >= 1) return '${d.inDays}일';
    if (d.inMinutes >= 1) return '${d.inMinutes}분';
    return '곧';
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/ui/review_controller_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: DeckListController 구현 (단순 로더)**

`lib/ui/controllers/deck_list_controller.dart`:
```dart
import 'package:flutter/foundation.dart';
import '../../srs/card_state.dart';
import '../../storage/deck_repository.dart';
import '../../storage/models.dart';

class DeckSummary {
  final Deck deck;
  final int total;
  final int due; // 오늘 학습/복습 대상 + 신규
  const DeckSummary({required this.deck, required this.total, required this.due});
}

class DeckListController extends ChangeNotifier {
  final DeckRepository repo;
  final DateTime Function() clock;
  DeckListController(this.repo, {DateTime Function()? clock})
      : clock = clock ?? DateTime.now;

  List<DeckSummary> summaries = [];
  bool loading = true;

  Future<void> load() async {
    loading = true;
    notifyListeners();
    final decks = await repo.getDecks();
    final now = clock();
    final result = <DeckSummary>[];
    for (final d in decks) {
      final cards = await repo.getCards(d.id);
      final due = cards
          .where((c) =>
              c.state.status == CardStatus.newCard ||
              !c.state.due.isAfter(now))
          .length;
      result.add(DeckSummary(deck: d, total: cards.length, due: due));
    }
    summaries = result;
    loading = false;
    notifyListeners();
  }

  Future<void> delete(String deckId) async {
    await repo.deleteDeck(deckId);
    await load();
  }
}
```

- [ ] **Step 6: Commit**

```bash
git add lib/ui/controllers/ test/ui/review_controller_test.dart
git commit -m "feat(ui): add deck list and review controllers"
```

---

## Task 12: UI 화면 & 앱 배선 (`ui/`, `main.dart`)

**Files:**
- Create: `lib/ui/widgets/card_view.dart`
- Create: `lib/ui/review_screen.dart`
- Create: `lib/ui/deck_list_screen.dart`
- Create: `lib/ui/import_screen.dart`
- Create: `lib/ui/app.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: 카드 렌더 위젯**

`lib/ui/widgets/card_view.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

class CardView extends StatelessWidget {
  final String html;
  const CardView({super.key, required this.html});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: HtmlWidget(
        html,
        textStyle: const TextStyle(fontSize: 22),
        customStylesBuilder: (e) {
          if (e.classes.contains('cloze')) {
            return {'color': '#1565c0', 'font-weight': 'bold'};
          }
          return null;
        },
        // 미디어는 MVP 범위 밖: <img>는 플레이스홀더로 대체 (깨진 이미지 방지)
        customWidgetBuilder: (e) {
          if (e.localName == 'img') {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.image_not_supported_outlined, size: 18),
                SizedBox(width: 6),
                Text('(이미지 — 미지원)', style: TextStyle(fontSize: 14, color: Colors.grey)),
              ]),
            );
          }
          return null;
        },
      ),
    );
  }
}
```

> 참고: `[sound:...]` 텍스트는 그대로 표시된다(오디오 미지원). MVP 범위에 부합.

- [ ] **Step 2: 복습 화면**

`lib/ui/review_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../srs/card_state.dart';
import 'controllers/review_controller.dart';
import 'widgets/card_view.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReviewController>().load();
    });
  }

  void _onKey(KeyEvent e, ReviewController c) {
    if (e is! KeyDownEvent) return;
    if (!c.showingBack && e.logicalKey == LogicalKeyboardKey.space) {
      c.reveal();
    } else if (c.showingBack) {
      const map = {
        LogicalKeyboardKey.digit1: Rating.again,
        LogicalKeyboardKey.digit2: Rating.hard,
        LogicalKeyboardKey.digit3: Rating.good,
        LogicalKeyboardKey.digit4: Rating.easy,
      };
      final r = map[e.logicalKey];
      if (r != null) c.rate(r);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ReviewController>();
    return Scaffold(
      appBar: AppBar(title: Text('복습 (남은 카드 ${c.remaining})')),
      body: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        autofocus: true,
        onKeyEvent: (e) => _onKey(e, c),
        child: _body(context, c),
      ),
    );
  }

  Widget _body(BuildContext context, ReviewController c) {
    if (c.loading) return const Center(child: CircularProgressIndicator());
    if (c.isDone) {
      return const Center(child: Text('오늘 학습 완료! 🎉', style: TextStyle(fontSize: 24)));
    }
    final card = c.current!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Expanded(child: Center(
            child: CardView(html: c.showingBack ? card.backHtml : card.frontHtml))),
          const SizedBox(height: 16),
          if (!c.showingBack)
            FilledButton(
              onPressed: c.reveal,
              child: const Text('정답 보기 (Space)'),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _rateButton(c, Rating.again, '다시', Colors.red),
                _rateButton(c, Rating.hard, '어려움', Colors.orange),
                _rateButton(c, Rating.good, '좋음', Colors.green),
                _rateButton(c, Rating.easy, '쉬움', Colors.blue),
              ],
            ),
        ],
      ),
    );
  }

  Widget _rateButton(ReviewController c, Rating r, String label, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: color),
          onPressed: () => c.rate(r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [Text(label), Text(c.previewLabel(r), style: const TextStyle(fontSize: 11))],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: 덱 목록 화면**

`lib/ui/deck_list_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../srs/scheduler.dart';
import '../storage/deck_repository.dart';
import 'controllers/deck_list_controller.dart';
import 'controllers/review_controller.dart';
import 'import_screen.dart';
import 'review_screen.dart';

class DeckListScreen extends StatefulWidget {
  const DeckListScreen({super.key});
  @override
  State<DeckListScreen> createState() => _DeckListScreenState();
}

class _DeckListScreenState extends State<DeckListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeckListController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DeckListController>();
    final repo = context.read<DeckRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('내 덱')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ImportScreen()));
          if (context.mounted) context.read<DeckListController>().load();
        },
        icon: const Icon(Icons.add),
        label: const Text('덱 가져오기'),
      ),
      body: c.loading
          ? const Center(child: CircularProgressIndicator())
          : c.summaries.isEmpty
              ? const Center(child: Text('가져온 덱이 없습니다. + 버튼으로 .apkg를 추가하세요.'))
              : ListView(
                  children: c.summaries.map((s) {
                    return ListTile(
                      title: Text(s.deck.name),
                      subtitle: Text('총 ${s.total}장 · 오늘 ${s.due}장'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => c.delete(s.deck.id),
                      ),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider(
                            create: (_) => ReviewController(
                              repo: repo,
                              scheduler: const Scheduler(),
                              deckId: s.deck.id,
                              newLimit: 20,
                              reviewLimit: 200,
                            ),
                            child: const ReviewScreen(),
                          ),
                        )).then((_) => c.load());
                      },
                    );
                  }).toList(),
                ),
    );
  }
}
```

- [ ] **Step 4: Import 화면**

`lib/ui/import_screen.dart`:
```dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../apkg/anki_db.dart';
import '../apkg/apkg_reader.dart';
import '../apkg/collection_opener_web.dart';
import '../storage/deck_repository.dart';
import '../storage/import_service.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});
  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  String _status = '';
  bool _busy = false;

  Future<void> _pickAndImport() async {
    setState(() { _busy = true; _status = '파일 선택 중...'; });
    try {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['apkg'], withData: true);
      if (result == null || result.files.single.bytes == null) {
        setState(() { _busy = false; _status = '취소됨'; });
        return;
      }
      setState(() => _status = '압축 해제 중...');
      final dbBytes = ApkgReader.extractCollection(result.files.single.bytes!);

      setState(() => _status = '카드 읽는 중...');
      final db = await WebCollectionOpener().open(dbBytes);
      final reader = AnkiCollectionReader(db);
      final decks = reader.readDecks();
      final cards = reader.readCards();
      db.dispose();

      setState(() => _status = '저장 중...');
      final repo = context.read<DeckRepository>();
      final saved = await ImportService(repo)
          .importParsed(decks: decks, cards: cards, now: DateTime.now());

      setState(() { _busy = false; _status = '완료: ${saved.length}개 덱, ${cards.length}장 가져옴'; });
      if (mounted) Navigator.pop(context);
    } on UnsupportedApkgException catch (e) {
      setState(() { _busy = false; _status = e.message; });
    } catch (e) {
      setState(() { _busy = false; _status = '가져오기 실패: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('덱 가져오기')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Anki에서 덱을 내보낼 때 "이전 Anki 버전 지원"을 체크한 .apkg를 선택하세요.',
                textAlign: TextAlign.center,
              ),
            ),
            FilledButton.icon(
              onPressed: _busy ? null : _pickAndImport,
              icon: const Icon(Icons.upload_file),
              label: const Text('.apkg 파일 선택'),
            ),
            const SizedBox(height: 16),
            if (_busy) const CircularProgressIndicator(),
            Text(_status),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: 앱 루트 & main**

`lib/ui/app.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sembast/sembast.dart';
import '../storage/deck_repository.dart';
import 'controllers/deck_list_controller.dart';
import 'deck_list_screen.dart';

class AnkiyoApp extends StatelessWidget {
  final Database db;
  const AnkiyoApp({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    final repo = DeckRepository(db);
    return MultiProvider(
      providers: [
        Provider<DeckRepository>.value(value: repo),
        ChangeNotifierProvider(create: (_) => DeckListController(repo)),
      ],
      child: MaterialApp(
        title: 'ankiyo',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: const DeckListScreen(),
      ),
    );
  }
}
```

`lib/main.dart` (전체 교체):
```dart
import 'package:flutter/material.dart';
import 'storage/db.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await openAppDatabase();
  runApp(AnkiyoApp(db: db));
}
```

- [ ] **Step 6: 정적 분석 & 빌드 확인**

Run: `flutter analyze`
Expected: "No issues found!" (사소한 경고는 수정).

Run: `flutter build web`
Expected: 빌드 성공, `build/web/` 생성.

- [ ] **Step 7: Commit**

```bash
git add lib/ui/ lib/main.dart
git commit -m "feat(ui): add import, deck list, and review screens"
```

---

## Task 13: 일일 한도 설정 (`storage/settings_store.dart`, `ui/settings_screen.dart`)

**Files:**
- Create: `lib/storage/settings_store.dart`
- Create: `lib/ui/controllers/settings_controller.dart`
- Create: `lib/ui/settings_screen.dart`
- Modify: `lib/ui/app.dart`
- Modify: `lib/ui/deck_list_screen.dart`
- Test: `test/storage/settings_store_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/storage/settings_store_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:ankiyo/storage/settings_store.dart';

void main() {
  test('기본값을 반환하고 저장/로드된다', () async {
    final db = await databaseFactoryMemory.openDatabase('s.db');
    final store = SettingsStore(db);

    final defaults = await store.load();
    expect(defaults.newLimit, 20);
    expect(defaults.reviewLimit, 200);

    await store.save(const SrsSettings(newLimit: 5, reviewLimit: 50));
    final loaded = await store.load();
    expect(loaded.newLimit, 5);
    expect(loaded.reviewLimit, 50);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/storage/settings_store_test.dart`
Expected: FAIL — `SettingsStore` 없음.

- [ ] **Step 3: SettingsStore 구현**

`lib/storage/settings_store.dart`:
```dart
import 'package:sembast/sembast.dart';

class SrsSettings {
  final int newLimit;
  final int reviewLimit;
  const SrsSettings({this.newLimit = 20, this.reviewLimit = 200});

  Map<String, Object?> toMap() =>
      {'newLimit': newLimit, 'reviewLimit': reviewLimit};

  factory SrsSettings.fromMap(Map<String, Object?> m) => SrsSettings(
        newLimit: (m['newLimit'] as num?)?.toInt() ?? 20,
        reviewLimit: (m['reviewLimit'] as num?)?.toInt() ?? 200,
      );
}

class SettingsStore {
  final Database _db;
  final _store = stringMapStoreFactory.store('settings');
  static const _key = 'srs';

  SettingsStore(this._db);

  Future<SrsSettings> load() async {
    final m = await _store.record(_key).get(_db);
    return m == null ? const SrsSettings() : SrsSettings.fromMap(m);
  }

  Future<void> save(SrsSettings s) async {
    await _store.record(_key).put(_db, s.toMap());
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/storage/settings_store_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: SettingsController 구현**

`lib/ui/controllers/settings_controller.dart`:
```dart
import 'package:flutter/foundation.dart';
import '../../storage/settings_store.dart';

class SettingsController extends ChangeNotifier {
  final SettingsStore store;
  SettingsController(this.store);

  SrsSettings settings = const SrsSettings();

  Future<void> load() async {
    settings = await store.load();
    notifyListeners();
  }

  Future<void> update(SrsSettings s) async {
    settings = s;
    await store.save(s);
    notifyListeners();
  }
}
```

- [ ] **Step 6: 설정 화면 구현**

`lib/ui/settings_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../storage/settings_store.dart';
import 'controllers/settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<SettingsController>();
    final s = c.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('하루 신규 카드 한도: ${s.newLimit}'),
          Slider(
            value: s.newLimit.toDouble(),
            min: 0, max: 100, divisions: 100,
            label: '${s.newLimit}',
            onChanged: (v) => c.update(
                SrsSettings(newLimit: v.round(), reviewLimit: s.reviewLimit)),
          ),
          const SizedBox(height: 24),
          Text('하루 복습 카드 한도: ${s.reviewLimit}'),
          Slider(
            value: s.reviewLimit.toDouble(),
            min: 0, max: 1000, divisions: 100,
            label: '${s.reviewLimit}',
            onChanged: (v) => c.update(
                SrsSettings(newLimit: s.newLimit, reviewLimit: v.round())),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: app.dart에 SettingsController 등록**

`lib/ui/app.dart` 수정 — import 추가:
```dart
import '../storage/settings_store.dart';
import 'controllers/settings_controller.dart';
```
providers 리스트 교체:
```dart
      providers: [
        Provider<DeckRepository>.value(value: repo),
        ChangeNotifierProvider(create: (_) => DeckListController(repo)),
        ChangeNotifierProvider(
            create: (_) => SettingsController(SettingsStore(db))..load()),
      ],
```

- [ ] **Step 8: deck_list_screen.dart에서 설정 사용**

`lib/ui/deck_list_screen.dart` 수정 — import 추가:
```dart
import 'controllers/settings_controller.dart';
import 'settings_screen.dart';
```
`build` 시작부에 설정 읽기 추가:
```dart
    final c = context.watch<DeckListController>();
    final repo = context.read<DeckRepository>();
    final settings = context.watch<SettingsController>().settings;
```
AppBar에 설정 버튼 추가 — 교체:
```dart
      appBar: AppBar(title: const Text('내 덱'), actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
      ]),
```
ReviewController 생성 시 하드코딩된 한도를 설정값으로 교체:
```dart
                            create: (_) => ReviewController(
                              repo: repo,
                              scheduler: const Scheduler(),
                              deckId: s.deck.id,
                              newLimit: settings.newLimit,
                              reviewLimit: settings.reviewLimit,
                            ),
```

- [ ] **Step 9: 정적 분석 확인**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 10: Commit**

```bash
git add lib/storage/settings_store.dart lib/ui/controllers/settings_controller.dart lib/ui/settings_screen.dart lib/ui/app.dart lib/ui/deck_list_screen.dart test/storage/settings_store_test.dart
git commit -m "feat(settings): add daily new/review limit settings"
```

---

## Task 14: 위젯/통합 테스트 & 수동 E2E

**Files:**
- Create: `test/ui/review_screen_test.dart`

- [ ] **Step 1: 복습 화면 위젯 테스트**

`test/ui/review_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:ankiyo/srs/card_state.dart';
import 'package:ankiyo/srs/scheduler.dart';
import 'package:ankiyo/storage/deck_repository.dart';
import 'package:ankiyo/storage/models.dart';
import 'package:ankiyo/ui/controllers/review_controller.dart';
import 'package:ankiyo/ui/review_screen.dart';

void main() {
  testWidgets('앞면 → 정답 보기 → 평가 흐름', (tester) async {
    final now = DateTime.utc(2026, 1, 1, 9);
    final db = await databaseFactoryMemory.openDatabase('w.db');
    final repo = DeckRepository(db);
    await repo.saveDeck(Deck(id: 'd1', name: 'D', importedAt: now), [
      StudyCard(id: 'c1', deckId: 'd1', frontHtml: '<b>앞</b>', backHtml: '뒤',
          isCloze: false, state: CardState.create(now)),
    ]);

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider(
        create: (_) => ReviewController(
          repo: repo, scheduler: const Scheduler(), deckId: 'd1',
          newLimit: 20, reviewLimit: 200, clock: () => now),
        child: const ReviewScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('정답 보기 (Space)'), findsOneWidget);
    await tester.tap(find.text('정답 보기 (Space)'));
    await tester.pumpAndSettle();

    expect(find.text('좋음'), findsOneWidget);
    await tester.tap(find.text('좋음'));
    await tester.pumpAndSettle();

    expect(find.text('오늘 학습 완료! 🎉'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 전체 테스트 실행**

Run: `flutter test`
Expected: 모든 테스트 PASS.

- [ ] **Step 3: 수동 E2E (브라우저)**

Run: `flutter run -d chrome`
체크리스트:
1. 빈 덱 목록 → "덱 가져오기" → 실제 구형 `.apkg` 선택 → import 완료
2. 덱 목록에 덱이 뜨고 카드 수가 보임
3. 덱 탭 → 앞면 표시 → "정답 보기" → 뒷면 + 4버튼 (각 버튼에 다음 간격)
4. "좋음" 평가 → 다음 카드, 다 끝나면 완료 화면
5. 새로고침 후에도 진도 유지(IndexedDB) — 같은 카드가 다시 학습 대상이면 일정대로 노출
6. 신형(zstd) `.apkg` 선택 시 친절한 한국어 안내 메시지

문제가 있으면 superpowers:systematic-debugging으로 근본 원인부터 조사한다.

- [ ] **Step 4: Commit**

```bash
git add test/ui/review_screen_test.dart
git commit -m "test(ui): add review screen widget test"
```

---

## 완료 기준 (Definition of Done)

- [ ] `flutter test` 전체 통과
- [ ] `flutter analyze` 무경고
- [ ] `flutter build web` 성공
- [ ] 실제 구형 `.apkg`를 가져와 SRS 복습이 동작
- [ ] 새로고침 후 진도 유지
- [ ] 신형/잘못된 파일에 대해 명확한 안내 메시지
- [ ] cloze 덱이 앞/뒤로 정상 렌더
