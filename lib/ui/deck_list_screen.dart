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
              ? const Center(
                  child: Text('가져온 덱이 없습니다. + 버튼으로 .apkg를 추가하세요.'))
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(
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
                          ),
                        ).then((_) => c.load());
                      },
                    );
                  }).toList(),
                ),
    );
  }
}
