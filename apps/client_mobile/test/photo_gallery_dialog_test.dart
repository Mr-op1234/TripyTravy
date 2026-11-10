import 'package:client_mobile/ui/widgets/photo_gallery_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens the tapped photo and swipes within the gallery',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: PhotoGalleryDialog(
        photos: const ['First', 'Second', 'Third'],
        initialIndex: 1,
        imageBuilder: (photo) =>
            SizedBox.expand(child: Center(child: Text(photo))),
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Second'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('Third'), findsOneWidget);
    expect(find.text('3 / 3'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(find.text('Second'), findsOneWidget);
  });
}
