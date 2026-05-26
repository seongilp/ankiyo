# Anki 학습 웹앱 (ankiyo) — 설계 문서

- **작성일**: 2026-05-26
- **상태**: 승인됨 (구현 대기)
- **목표 플랫폼**: 웹 우선 → 이후 네이티브(iOS/Android) 포팅

## 1. 개요

`.apkg`(Anki 덱 내보내기) 파일을 읽어, 브라우저 안에서 간격 반복(SRS) 방식으로
공부할 수 있는 Flutter 웹앱. 백엔드 없이 모든 처리를 클라이언트에서 수행하고,
학습 진도는 브라우저 로컬(IndexedDB)에 저장한다.

### 핵심 결정 사항

| 항목 | 결정 |
|------|------|
| 학습 방식 | 풀 SRS 스케줄링 (Anki식, 자체 SM-2 변형) |
| 입력 형식 | `.apkg` (구형/비압축 우선, 텍스트 카드 중심) |
| 미디어 | MVP 제외 (이미지/오디오는 플레이스홀더 처리) |
| 진도 저장 | 브라우저 IndexedDB (Hive), 백엔드 없음 |
| 카드 렌더링 | HTML 서식 + cloze(빈칸 채우기) 지원 |
| 신형 zstd `.apkg` | MVP 제외 (후속 작업) |

## 2. 아키텍처 / 모듈 구조

레이어를 명확히 나눠 각 모듈이 한 가지 책임만 갖게 한다. `apkg/`와 `srs/`는
순수 로직(I/O·UI 없음)으로 단독 테스트가 쉽고 네이티브 포팅 시 그대로 재사용된다.

```
lib/
├── apkg/                  # .apkg 파싱 (플랫폼 무관)
│   ├── apkg_reader.dart       # zip 해제 → collection.anki21 추출
│   ├── anki_db.dart           # sqlite3로 col/notes/cards 읽기
│   ├── note_type.dart         # 노트 타입(필드/템플릿) 파싱
│   └── card_builder.dart      # 템플릿+필드 → 앞/뒤 HTML 생성, cloze 처리
├── srs/                   # 복습 일정 엔진 (순수 Dart, 부수효과 없음)
│   ├── scheduler.dart         # SM-2 변형: 등급→다음 일정 계산
│   └── card_state.dart        # 카드 스케줄 상태 모델 (불변)
├── storage/               # 영속성 (IndexedDB via Hive)
│   ├── deck_repository.dart   # 덱/카드 저장·조회
│   └── progress_store.dart    # 스케줄 상태 저장
├── study/                 # 학습 세션 로직
│   └── review_queue.dart      # 오늘 복습/신규 카드 큐 구성
├── ui/                    # 화면
│   ├── import_screen.dart
│   ├── deck_list_screen.dart
│   ├── review_screen.dart
│   └── widgets/
└── main.dart
```

import용 sqlite는 1회성으로 사용하고, 이후 런타임에는 우리 자체 저장소(Hive)만 사용한다.

### 기술 스택

- **Flutter (web 타깃)** — 이후 모바일 포팅 대비 플랫폼 의존 코드 최소화
- `archive` — `.apkg`(zip) 해제
- `sqlite3` (+ WASM) — `collection.anki21` 1회 읽기 (웹: wasm, 네이티브: FFI 공통)
- `hive` / `hive_flutter` — IndexedDB 기반 카드·스케줄 영속성
- `flutter_widget_from_html` — 카드 HTML 렌더링
- 상태관리: `riverpod` (또는 `provider`)
- cloze·템플릿 처리: 자체 구현

## 3. 데이터 흐름

### Import 흐름 (1회성)

```
.apkg 업로드 → archive로 zip 해제 → collection.anki21(SQLite) 추출
  → sqlite3 WASM으로 열기
  → col 테이블: models(노트타입 JSON), decks 파싱
  → notes 테이블: 필드값(\x1f 구분) 추출
  → cards 테이블: nid, ord(템플릿 번호), did(덱) 추출
  → card_builder: 템플릿+필드 → 앞/뒤 HTML, cloze 전개
  → Hive에 Deck + StudyCard로 저장 (sqlite는 여기서 폐기)
```

import 시 Anki의 기존 일정(due/ivl/factor)은 무시하고 **전부 신규 카드로 시작**한다.

### 학습 흐름 (반복)

```
덱 선택 → review_queue가 오늘 대상 카드 추림
  → 앞면 표시 → "정답 보기" → 뒷면 표시
  → Again/Hard/Good/Easy 평가
  → scheduler가 다음 일정 계산 → progress_store 저장 → 다음 카드
```

## 4. 데이터 모델 (Hive, 불변 객체로 갱신)

```dart
Deck { id, name, importedAt }

StudyCard {            // Anki 카드 1장 = 우리 카드 1장
  id, deckId,
  frontHtml, backHtml, // 미리 렌더된 HTML
  isCloze,
  // --- 스케줄 상태 (SRS가 갱신) ---
  status,              // new | learning | review | relearning
  due,                 // 다음 복습 시각
  intervalDays,
  easeFactor,          // 기본 2.5
  reps, lapses,
  learningStepIndex,
}
```

모든 갱신은 새 객체를 반환하는 불변 패턴으로 처리한다 (in-place 변경 금지).

## 5. SRS 엔진 (SM-2 변형)

Anki의 정확한 v2/FSRS를 그대로 복제하지 않고, 충실하지만 단순한 SM-2 변형으로 구현한다.

- **신규/학습 단계**: 학습 스텝 `[1분, 10분]` → 졸업 시 1일
- **복습 카드**: `다음 간격 = 현재 간격 × easeFactor`, 등급에 따라 ease 조정
  - **Again**: lapse 처리, relearning 진입, ease −0.20
  - **Hard**: 간격 × 1.2, ease −0.15
  - **Good**: 간격 × ease (표준)
  - **Easy**: 간격 × ease × 1.3, ease +0.15
- **하루 한도**: 신규/복습 카드 일일 상한 (설정 가능, 기본 신규 20 · 복습 200)
- `scheduler.dart`는 `(현재 상태, 등급, 지금 시각) → 새 상태`인 **순수 함수**.

## 6. 카드 렌더링 (HTML + cloze)

- **HTML 렌더링**: `flutter_widget_from_html`로 `<b>`, `<div>`, 줄바꿈, 표, 색상 등 표시.
  `<img>`/`[sound:]`는 미디어 제외이므로 플레이스홀더 또는 숨김 처리.
- **cloze 처리**: `card_builder`가 import 시점에 전개
  - 앞면: `{{c1::정답::힌트}}` → `[힌트]` 또는 `[...]`, 같은 카드의 다른 클로즈(c2 등)는 노출
  - 뒷면: 가린 부분을 강조 표시해 정답 공개
  - 노트 1개에 cloze 번호가 여러 개면 → 카드 여러 장 생성 (Anki와 동일)
- **템플릿 문법**: `{{Field}}` 치환, `{{FrontSide}}`, `{{#Field}}...{{/Field}}` 조건부 기본 지원.
  미지원 고급 문법은 안전하게 생략(앱이 죽지 않도록).

## 7. UI 화면

1. **Import 화면**: `.apkg` 드래그&드롭/파일 선택, 진행률, "이전 Anki 버전 지원 체크 후 내보내기" 안내
2. **덱 목록**: 덱별 신규/복습/총 카드 수 배지, 학습 시작 버튼, 덱 삭제
3. **복습 화면**: 앞면 → "정답 보기" → 뒷면 + 4개 평가 버튼(각 버튼에 다음 간격 미리보기),
   남은 카드 수, 키보드 단축키(스페이스 / 1~4)
4. **(간단) 설정**: 일일 신규/복습 한도

## 8. 에러 처리 & 검증 (경계에서 방어)

- 잘못된/신형(zstd) `.apkg` → 명확한 한국어 메시지
  ("이 파일은 신형 포맷이라 아직 지원되지 않습니다. 이전 버전 지원으로 다시 내보내 주세요")
- SQLite 스키마 누락/깨진 노트 → 해당 카드만 건너뛰고 import 계속, 건너뛴 수 보고
- 알 수 없는 템플릿 문법 → 죽지 않고 원문 또는 빈 값으로 폴백
- 저장 실패 → 사용자에게 알리고 부분 import 롤백

## 9. 테스트 전략

- **단위**: `scheduler`(등급별 일정 계산 — 핵심), `card_builder`(cloze 전개·템플릿 치환),
  `apkg_reader`(샘플 `.apkg` 픽스처로 파싱)
- **통합**: import → 저장 → 복습 큐 구성 전체 경로
- **위젯/E2E**: 복습 화면 흐름(앞→뒤→평가→다음)
- TDD로 진행하며 `scheduler`·`card_builder`부터 테스트 우선 작성.
  작은 샘플 `.apkg` 픽스처를 준비한다.

## 10. 범위 밖 (Non-goals, MVP 기준)

- 신형 zstd `.apkg` / `.colpkg` 전체 컬렉션
- 이미지·오디오 미디어 재생
- 클라우드 동기화 / 계정 / 다기기 동기화
- 카드 편집·생성 (읽기·학습 전용)
- AnkiWeb 직접 연동
- FSRS 등 고급 스케줄러

## 11. 후속 작업 (Post-MVP)

- 신형 zstd `.apkg` 지원 (zstd WASM 디코더 번들)
- 미디어(이미지/오디오) 지원
- 진도 JSON 내보내기/가져오기 (기기 간 이동)
- 네이티브(iOS/Android) 포팅
