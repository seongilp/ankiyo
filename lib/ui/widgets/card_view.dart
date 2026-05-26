import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

class CardView extends StatelessWidget {
  final String html;
  const CardView({super.key, required this.html});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: HtmlWidget(
        html,
        textStyle: TextStyle(
          fontSize: 23,
          height: 1.5,
          color: scheme.onSurface,
          letterSpacing: -0.2,
        ),
        customStylesBuilder: (e) {
          if (e.classes.contains('cloze')) {
            final hex =
                '#${(scheme.primary.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
            return {'color': hex, 'font-weight': '700'};
          }
          return null;
        },
        // 미디어는 MVP 범위 밖: <img>는 플레이스홀더로 대체 (깨진 이미지 방지)
        customWidgetBuilder: (e) {
          if (e.localName == 'img') {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.image_not_supported_outlined,
                    size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('(이미지 — 미지원)',
                    style: TextStyle(
                        fontSize: 14, color: scheme.onSurfaceVariant)),
              ]),
            );
          }
          return null;
        },
      ),
    );
  }
}
