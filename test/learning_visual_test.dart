import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello/app_style.dart';
import 'package:hello/features/learning/bobo_chat.dart';
import 'package:hello/features/learning/exercise_interactions.dart';
import 'package:hello/services/bobo_api.dart';

void main() {
  setUpAll(() async {
    for (final entry in {
      'Arial': Platform.environment['HOWBUDDY_TEXT_FONT'],
      'MaterialIcons': Platform.environment['HOWBUDDY_ICON_FONT'],
    }.entries) {
      if (entry.value == null) continue;
      final loader = FontLoader(entry.key);
      loader.addFont(
        File(
          entry.value!,
        ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
      await loader.load();
    }
  });
  testWidgets('chat loading, error, retry and empty conversation have usable controls', (tester) async {
    var opens = 0;
    final loading = Completer<BoboConversation>();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: BoboChatPanel(
      lessonTitle: 'Cells', exerciseIndex: null, answerSubmitted: false, answerCorrect: null,
      onOpen: () { opens++; return opens == 1 ? loading.future : Future.value(const BoboConversation(id: 'ready', messages: [])); },
      onSend: (_, _, _) async => 'A reply', onClear: (_) async => const BoboConversation(id: 'ready', messages: []),
    ))));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    loading.completeError(const BoboApiException('unavailable'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Try again'));
    await tester.pumpAndSettle();
    expect(opens, 2);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    expect(tester.widget<IconButton>(find.byWidgetPredicate((widget) => widget is IconButton && widget.tooltip == 'Send message')).onPressed, isNull);
  });

  testWidgets('keyboard send failure retains draft and retry succeeds', (tester) async {
    var sends = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: BoboChatPanel(
      lessonTitle: 'Cells', exerciseIndex: null, answerSubmitted: false, answerCorrect: null,
      onOpen: () async => const BoboConversation(id: 'ready', messages: []),
      onSend: (_, _, _) async { if (++sends == 1) throw const BoboApiException('unavailable'); return 'Try thinking about energy.'; },
      onClear: (_) async => const BoboConversation(id: 'ready', messages: []),
    ))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'How do cells live?');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'How do cells live?');
    await tester.showKeyboard(find.byType(TextField));
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(sends, 2);
    expect(find.text('Try thinking about energy.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
  });
  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Bobo renders at 360px dark=$dark text=$scale with reduced motion',
        (tester) async {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          AppColors.isDarkMode = dark;
          addTearDown(() => AppColors.isDarkMode = false);
          final boundary = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(360, 800),
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                child: RepaintBoundary(
                  key: boundary,
                  child: Scaffold(
                    body: SafeArea(
                      child: BoboChatPanel(
                        lessonTitle: 'What makes a cell alive?',
                        exerciseIndex: 0,
                        answerSubmitted: true,
                        answerCorrect: false,
                        onOpen: () async => const BoboConversation(
                          id: 'test',
                          messages: [
                            BoboChatTurn(
                              role: 'assistant',
                              content:
                                  'Cells use energy. What do you think they need to stay alive?',
                            ),
                          ],
                        ),
                        onSend: (_, _, _) async =>
                            'Let’s explore that together.',
                        onClear: (_) async =>
                            const BoboConversation(id: 'test', messages: []),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byTooltip('Send message'), findsOneWidget);
          await tester.enterText(
            find.byType(TextField),
            'How do cells use energy?',
          );
        await tester.pump();
          await tester.tap(find.byTooltip('Send message'));
          await tester.pumpAndSettle();
          expect(find.text('Let’s explore that together.'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              'build/audit/bobo-${dark ? 'dark' : 'light'}-${scale.toInt()}x.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        },
      );
    }
  }

  testWidgets('word choices expose selection and minimum touch targets', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpotMistakeInteraction(
            tokens: const ['Cells', 'rocks'],
            selected: 'rocks',
            locked: false,
            onSelect: (_) {},
          ),
        ),
      ),
    );
    expect(tester.getSize(find.text('Cells')).height, greaterThan(0));
    final selected = tester.getSemantics(find.text('rocks'));
    expect(selected.flagsCollection.isSelected, ui.Tristate.isTrue);
    expect(
      tester.getSize(find.byType(InkWell).first).height,
      greaterThanOrEqualTo(48),
    );
    semantics.dispose();
  });
}
