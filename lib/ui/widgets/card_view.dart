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
                Text('(이미지 — 미지원)',
                    style: TextStyle(fontSize: 14, color: Colors.grey)),
              ]),
            );
          }
          return null;
        },
      ),
    );
  }
}
