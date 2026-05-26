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
  bool _error = false;

  Future<void> _pickAndImport() async {
    setState(() {
      _busy = true;
      _error = false;
      _status = '파일 선택 중...';
    });
    try {
      final result = await FilePicker.pickFiles(
          type: FileType.custom, allowedExtensions: ['apkg'], withData: true);
      if (result == null || result.files.single.bytes == null) {
        setState(() {
          _busy = false;
          _status = '';
        });
        return;
      }
      setState(() => _status = '압축 해제 중...');
      final dbBytes = ApkgReader.extractCollection(result.files.single.bytes!);

      setState(() => _status = '카드 읽는 중...');
      final db = await WebCollectionOpener().open(dbBytes);
      final reader = AnkiCollectionReader(db);
      final decks = reader.readDecks();
      final cards = reader.readCards();
      db.close();

      setState(() => _status = '저장 중...');
      if (!mounted) return;
      final repo = context.read<DeckRepository>();
      await ImportService(repo)
          .importParsed(decks: decks, cards: cards, now: DateTime.now());

      if (!mounted) return;
      Navigator.pop(context);
    } on UnsupportedApkgException catch (e) {
      setState(() {
        _busy = false;
        _error = true;
        _status = e.message;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = true;
        _status = '가져오기 실패: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('덱 가져오기')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DropZone(busy: _busy, onTap: _busy ? null : _pickAndImport),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 18, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Anki에서 내보낼 때 "이전 Anki 버전 지원"을 체크한 .apkg를 선택하세요.',
                          style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_status.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_busy)
                        const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2)),
                      if (_busy) const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          _status,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _error
                                ? scheme.error
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DropZone extends StatelessWidget {
  final bool busy;
  final VoidCallback? onTap;
  const _DropZone({required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: scheme.outlineVariant, width: 1.5),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.upload_file_rounded,
                    size: 30, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Text('.apkg 파일 선택',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface)),
              const SizedBox(height: 4),
              Text('탭해서 파일을 고르세요',
                  style: TextStyle(
                      fontSize: 13, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
