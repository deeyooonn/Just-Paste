import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:justpaste/main.dart';
import 'package:justpaste/ui/dashboard_view.dart';
import 'package:justpaste/ui/login_screen.dart';
import 'package:justpaste/ui/nocturne_theme.dart';

class TestUser extends Fake implements User {
  @override
  final bool isAnonymous;
  @override
  String get uid => isAnonymous ? 'old-guest' : 'test-reader';
  @override
  String get displayName => 'Alex';
  @override
  String get email => 'alex@example.com';
  @override
  String? get photoURL => null;
  TestUser({this.isAnonymous = false});
}

final sampleCards = [
  Flashcard(
    question: 'Why do we remember some ideas more clearly than others?',
    answer:
        'Active recall strengthens memory by asking us to retrieve an idea, rather than simply reread it.',
  ),
  Flashcard(
    question: 'What is spaced repetition?',
    answer:
        'Reviewing material at increasing intervals to strengthen long-term retention.',
  ),
];

Widget testApp(Widget child, {double textScale = 1}) => RepaintBoundary(
  key: const Key('preview'),
  child: MaterialApp(
    theme: NocturneTheme.theme,
    debugShowCheckedModeBanner: false,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: child,
  ),
);

Future<void> phone(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_UI_PREVIEWS')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('preview')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/ui-previews')
      ..createSync(recursive: true);
    File(
      '${directory.path}/$name.png',
    ).writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

DashboardView dashboard({
  ValueChanged<String>? onGenerate,
  VoidCallback? onCamera,
  VoidCallback? onImport,
  VoidCallback? onLibrary,
  bool busy = false,
}) => DashboardView(
  displayName: 'Alex',
  avatar: const CircleAvatar(radius: 17, child: Text('A')),
  onLibrary: onLibrary ?? () {},
  onCamera: onCamera ?? () {},
  onImport: onImport ?? () {},
  onGenerate: onGenerate ?? (_) {},
  isProcessing: busy,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final font in ['Inter', 'CormorantGaramond']) {
      await (FontLoader(
        font,
      )..addFont(rootBundle.load('assets/fonts/$font.ttf'))).load();
    }
  });

  testWidgets('Waits for auth without exposing the dashboard', (tester) async {
    final auth = StreamController<User?>();
    addTearDown(auth.close);
    await tester.pumpWidget(testApp(AuthGate(authStateChanges: auth.stream)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(MainDashboardScreen), findsNothing);
    expect(find.byType(LoginScreen), findsNothing);
    auth.add(null);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('New users see login first', (tester) async {
    await phone(tester);
    await tester.pumpWidget(
      testApp(
        AuthGate(
          authStateChanges: Stream<User?>.value(null),
          onSignIn: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Log in to Just Paste'), findsOneWidget);
    expect(find.byType(MainDashboardScreen), findsNothing);
    expect(tester.takeException(), isNull);
    await capture(tester, 'login-phone');
  });

  testWidgets('Existing anonymous sessions cannot bypass login', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        AuthGate(
          authStateChanges: Stream<User?>.value(TestUser(isAnonymous: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(MainDashboardScreen), findsNothing);
  });

  testWidgets(
    'Authenticated sessions open dashboard and logout clears protected routes',
    (tester) async {
      final auth = StreamController<User?>();
      addTearDown(auth.close);
      await tester.pumpWidget(testApp(AuthGate(authStateChanges: auth.stream)));
      auth.add(TestUser());
      await tester.pumpAndSettle();
      expect(find.byType(MainDashboardScreen), findsOneWidget);
      final dashboardContext = tester.element(find.byType(MainDashboardScreen));
      unawaited(
        Navigator.of(dashboardContext).push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Protected study page')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Protected study page'), findsOneWidget);
      auth.add(null);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Protected study page'), findsNothing);
      expect(find.byType(MainDashboardScreen), findsNothing);
      auth.add(TestUser());
      await tester.pumpAndSettle();
      expect(find.byType(MainDashboardScreen), findsOneWidget);
      expect(find.text('Protected study page'), findsNothing);
    },
  );

  testWidgets('Auth errors stay on login', (tester) async {
    await tester.pumpWidget(
      testApp(
        AuthGate(authStateChanges: Stream<User?>.error(StateError('offline'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      find.textContaining('couldn’t connect to your account'),
      findsOneWidget,
    );
    expect(find.byType(MainDashboardScreen), findsNothing);
  });

  testWidgets('Sign-in prevents duplicate requests and recovers from failure', (
    tester,
  ) async {
    var calls = 0;
    final pending = Completer<void>();
    await phone(tester);
    await tester.pumpWidget(
      testApp(
        LoginScreen(
          onSignIn: () {
            calls++;
            return calls == 1 ? pending.future : Future<void>.value();
          },
        ),
      ),
    );
    final button = find.byKey(const Key('google-sign-in'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    expect(calls, 1);
    expect(find.text('Signing in…'), findsOneWidget);
    pending.completeError(
      FirebaseAuthException(code: 'network-request-failed'),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('You seem to be offline'), findsOneWidget);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.textContaining('You seem to be offline'), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('Login and dashboard fit a narrow phone at text scale $scale', (
      tester,
    ) async {
      await phone(tester, size: const Size(320, 640));
      await tester.pumpWidget(
        testApp(LoginScreen(onSignIn: () async {}), textScale: scale),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('google-sign-in')));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(testApp(dashboard(), textScale: scale));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Import a file'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Desktop login and dashboard fit wide layouts', (tester) async {
    await phone(tester, size: const Size(1280, 900));
    await tester.pumpWidget(testApp(LoginScreen(onSignIn: () async {})));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture(tester, 'login-desktop');
    await tester.pumpWidget(testApp(dashboard()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture(tester, 'dashboard-desktop');
  });

  testWidgets('Notes require content and generate with trimmed input', (
    tester,
  ) async {
    await phone(tester);
    String? submitted;
    await tester.pumpWidget(
      testApp(dashboard(onGenerate: (value) => submitted = value)),
    );
    final button = find.byKey(const Key('generate-flashcards'));
    expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('notes-input')), '   ');
    await tester.pump();
    expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
    await tester.enterText(
      find.byKey(const Key('notes-input')),
      '  Learning is the process of connecting new ideas to what we already know.  ',
    );
    await tester.pumpAndSettle();
    await capture(tester, 'dashboard-phone');
    await tester.ensureVisible(button);
    await tester.tap(button);
    expect(
      submitted,
      'Learning is the process of connecting new ideas to what we already know.',
    );
  });

  testWidgets('Clipboard, capture, import and library controls work', (
    tester,
  ) async {
    await phone(tester);
    var camera = 0;
    var imports = 0;
    var library = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async =>
          call.method == 'Clipboard.getData' ? {'text': 'A pasted idea'} : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      testApp(
        dashboard(
          onCamera: () => camera++,
          onImport: () => imports++,
          onLibrary: () => library++,
        ),
      ),
    );
    await tester.tap(find.text('Paste'));
    await tester.pumpAndSettle();
    expect(find.text('A pasted idea'), findsOneWidget);
    await tester.ensureVisible(find.text('Capture a page'));
    await tester.tap(find.text('Capture a page'));
    await tester.tap(find.text('Import a file'));
    await tester.tap(find.text('Library'));
    expect([camera, imports, library], [1, 1, 1]);
  });

  testWidgets('Busy generation blocks duplicate submission', (tester) async {
    await phone(tester);
    await tester.pumpWidget(testApp(dashboard(busy: true)));
    expect(
      tester.widget<TextField>(find.byKey(const Key('notes-input'))).enabled,
      isFalse,
    );
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const Key('generate-flashcards')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<ModalBarrier>(find.byKey(const Key('processing-barrier')))
          .dismissible,
      isFalse,
    );
    expect(
      tester.widget<PopScope>(find.byType(PopScope).first).canPop,
      isFalse,
    );
  });

  testWidgets('Library searches content and filters bookmarks', (tester) async {
    await phone(tester);
    final docs = [
      ProcessedDocument(
        id: '1',
        title: 'The art of remembering',
        createdAt: DateTime(2026, 10, 20),
        flashcards: sampleCards,
        isBookmarked: true,
      ),
      ProcessedDocument(
        id: '2',
        title: 'A closer look at the universe',
        createdAt: DateTime(2026, 10, 19),
        flashcards: [
          Flashcard(
            question: 'What is a star?',
            answer: 'A luminous sphere of plasma.',
          ),
        ],
      ),
    ];
    await tester.pumpWidget(
      testApp(ProfileScreen(user: TestUser(), documents: Stream.value(docs))),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'library-phone');
    await tester.tap(find.text('Bookmarked'));
    await tester.pumpAndSettle();
    expect(find.text('The art of remembering'), findsOneWidget);
    expect(find.text('A closer look at the universe'), findsNothing);
    await tester.tap(find.text('All decks'));
    await tester.enterText(find.byType(TextField), 'plasma');
    await tester.pumpAndSettle();
    expect(find.text('A closer look at the universe'), findsOneWidget);
    expect(find.text('The art of remembering'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Library distinguishes an empty collection from a failed load', (
    tester,
  ) async {
    await phone(tester);
    await tester.pumpWidget(
      testApp(ProfileScreen(user: TestUser(), documents: Stream.value([]))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your collection starts here'), findsOneWidget);
    await tester.pumpWidget(
      testApp(
        ProfileScreen(
          key: const Key('failed-library'),
          user: TestUser(),
          documents: Stream.error(StateError('offline')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your collection is out of reach'), findsOneWidget);
    expect(find.text('Your collection starts here'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Flashcards reveal answers, navigate, and switch to grid', (
    tester,
  ) async {
    await phone(tester);
    await tester.pumpWidget(
      testApp(
        ResultsScreen(
          title: 'The art of remembering',
          flashcards: sampleCards,
          userId: 'test-reader',
          isSaved: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'deck-phone');
    await tester.tap(find.text(sampleCards.first.question));
    await tester.pumpAndSettle();
    expect(find.text(sampleCards.first.answer), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Next card'));
    await tester.tap(find.byTooltip('Next card'));
    await tester.pumpAndSettle();
    expect(find.text(sampleCards.last.question), findsOneWidget);
    await tester.tap(find.text('Grid'));
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Library and flashcards support large text on small screens', (
    tester,
  ) async {
    await phone(tester, size: const Size(320, 640));
    await tester.pumpWidget(
      testApp(
        ProfileScreen(user: TestUser(), documents: Stream.value([])),
        textScale: 2,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      testApp(
        ResultsScreen(
          title: 'The art of remembering',
          flashcards: sampleCards,
          userId: 'test-reader',
          isSaved: true,
        ),
        textScale: 2,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Grid'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
