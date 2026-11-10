import 'package:client_mobile/ui/widgets/event_description.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripytravy_core/tripytravy_core.dart';

void main() {
  testWidgets(
      'exported event formatting renders cleanly with combined styles and lists',
      (tester) async {
    const description =
        '## Packing\n**Bold** *Italic* <u>Underline</u>\n==Yellow== ==red:Red== ==navy:Navy==\n==navy:***<u>Combined</u>***==\n1. First\n2. Second\n- Bullet\n* Another bullet\n**Across\nlines**';
    const trip = TripPackage(
        tripId: 'format-test',
        title: 'Formatting verification',
        startDateIso8601: '2026-11-07',
        endDateIso8601: '2026-11-07',
        primaryTimezoneIana: 'UTC',
        days: [
          ItineraryDay(
              dayNumber: 1,
              dateIso8601: '2026-11-07',
              title: 'Test',
              primaryTimezoneIana: 'UTC',
              events: [
                ItineraryEvent(
                    eventId: 'event',
                    eventType: EventType.activity,
                    title: 'Test',
                    startIso8601: '2026-11-07T09:00:00',
                    endIso8601: '2026-11-07T10:00:00',
                    timezoneIana: 'UTC',
                    description: description)
              ])
        ]);
    final storage = CasAttachmentStorageAdapter();
    final bytes = await ExportTripContainerUseCase(
            storage: storage, cipher: const TtrvContainerCipherAdapter())
        .execute(trip: trip);
    final restored = await ImportTripContainerUseCase(
            storage: storage, cipher: const TtrvContainerCipherAdapter())
        .execute(containerBytes: bytes);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: EventDescription(
                text: restored.days.first.events.first.description))));
    final rich = tester.widget<Text>(find.byType(Text).first).textSpan!;
    expect(rich.toPlainText(),
        'Packing\nBold Italic Underline\nYellow Red Navy\nCombined\n1. First\n2. Second\n• Bullet\n• Another bullet\nAcross\nlines');
    final leaves = <TextSpan>[];
    void collect(InlineSpan span) {
      if (span is TextSpan) {
        if (span.text != null) leaves.add(span);
        for (final child in span.children ?? <InlineSpan>[]) {
          collect(child);
        }
      }
    }

    collect(rich);
    TextStyle style(String text) =>
        leaves.firstWhere((s) => s.text == text).style!;
    expect(style('Bold').fontWeight, FontWeight.bold);
    expect(style('Italic').fontStyle, FontStyle.italic);
    expect(style('Underline').decoration, TextDecoration.underline);
    expect(style('Yellow').backgroundColor, const Color(0xFFFEF08A));
    expect(style('Red').backgroundColor, const Color(0xFFFECACA));
    expect(style('Navy').backgroundColor, const Color(0xFF1E3A8A));
    final combined = style('Combined');
    expect(combined.fontWeight, FontWeight.bold);
    expect(combined.fontStyle, FontStyle.italic);
    expect(combined.decoration, TextDecoration.underline);
    expect(combined.backgroundColor, const Color(0xFF1E3A8A));
    expect(combined.color, Colors.white);
  });
}
