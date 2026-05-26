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
    setState(() {
      _busy = true;
      _status = '파일 선택 중...';
    });
    try {
      final result = await FilePicker.pickFiles(
          type: FileType.custom, allowedExtensions: ['apkg'], withData: true);
      if (result == null || result.files.single.bytes == null) {
        setState(() {
          _busy = false;
          _status = '취소됨';
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
      final saved = await ImportService(repo)
          .importParsed(decks: decks, cards: cards, now: DateTime.now());

      setState(() {
        _busy = false;
        _status = '완료: ${saved.length}개 덱, ${cards.length}장 가져옴';
      });
      if (mounted) Navigator.pop(context);
    } on UnsupportedApkgException catch (e) {
      setState(() {
        _busy = false;
        _status = e.message;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _status = '가져오기 실패: $e';
      });
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
