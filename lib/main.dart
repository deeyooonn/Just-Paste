import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

import 'firebase_options.dart';
import 'gemini_flashcard_service.dart';
import 'ui/nocturne_theme.dart';
import 'ui/login_screen.dart';
import 'ui/dashboard_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: NocturneTheme.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  LicenseRegistry.addLicense(() async* {
    for (final family in ['Inter', 'CormorantGaramond']) {
      yield LicenseEntryWithLineBreaks([
        family,
      ], await rootBundle.loadString('assets/fonts/$family-OFL.txt'));
    }
  });

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Dotenv load note: $e");
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase init note: $e");
  }

  runApp(const JustPasteApp());
}

// -----------------------------------------------------------------------------
// DATA MODELS (FLASHCARDS ONLY)
// -----------------------------------------------------------------------------
class Flashcard {
  final String question;
  final String answer;

  Flashcard({required this.question, required this.answer});

  Map<String, dynamic> toJson() => {'question': question, 'answer': answer};

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      question: json['question']?.toString() ?? 'No Question',
      answer: json['answer']?.toString() ?? 'No Answer',
    );
  }
}

class ProcessedDocument {
  final String id;
  final String title;
  final DateTime createdAt;
  final List<Flashcard> flashcards;
  final bool isBookmarked;

  ProcessedDocument({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.flashcards,
    this.isBookmarked = false,
  });

  factory ProcessedDocument.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final rawCards = data['flashcards'] as List? ?? [];
    final cardList = rawCards
        .map((item) => Flashcard.fromJson(item as Map<String, dynamic>))
        .toList();

    final timestamp = data['createdAt'] as Timestamp?;

    return ProcessedDocument(
      id: doc.id,
      title: data['title']?.toString() ?? 'Untitled Document',
      createdAt: timestamp?.toDate() ?? DateTime.now(),
      flashcards: cardList,
      isBookmarked: data['isBookmarked'] as bool? ?? false,
    );
  }
}

// -----------------------------------------------------------------------------
// MAIN APP ROOT
// -----------------------------------------------------------------------------
class JustPasteApp extends StatelessWidget {
  const JustPasteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Just Paste',
      debugShowCheckedModeBanner: false,
      theme: NocturneTheme.theme,
      home: const AuthGate(),
    );
  }
}

// Signed-out and legacy anonymous sessions must authenticate before entering.
class AuthGate extends StatefulWidget {
  final Stream<User?>? authStateChanges;
  final Future<void> Function()? onSignIn;

  const AuthGate({super.key, this.authStateChanges, this.onSignIn});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Stream<User?> _authChanges;

  @override
  void initState() {
    super.initState();
    _connectAuth();
  }

  void _connectAuth() {
    try {
      _authChanges =
          widget.authStateChanges ?? FirebaseAuth.instance.authStateChanges();
    } catch (error) {
      _authChanges = Stream<User?>.error(error);
    }
  }

  Future<void> _signIn() async {
    if (widget.onSignIn != null) {
      await widget.onSignIn!();
      return;
    }
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      if (!mounted) return;
      setState(_connectAuth);
    }
    if (kIsWeb) {
      await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      return;
    }
    final googleSignIn = GoogleSignIn(
      serverClientId: dotenv.isInitialized
          ? dotenv.env['GOOGLE_CLIENT_ID']
          : null,
    );
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return;
    final googleAuth = await googleUser.authentication;
    await FirebaseAuth.instance.signInWithCredential(
      GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: _authChanges,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(
          body: NightBackdrop(
            child: Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Checking your sign-in',
                strokeWidth: 2,
              ),
            ),
          ),
        );
      }
      final user = snapshot.data;
      if (!snapshot.hasError && user != null && !user.isAnonymous) {
        return _SignedInNavigator(key: ValueKey(user.uid), user: user);
      }
      return LoginScreen(
        onSignIn: _signIn,
        connectionError: snapshot.hasError
            ? 'We couldn’t connect to your account. Please try signing in again.'
            : null,
      );
    },
  );
}

// Discard all protected routes when authentication changes or the user signs out.
class _SignedInNavigator extends StatefulWidget {
  final User user;
  const _SignedInNavigator({super.key, required this.user});

  @override
  State<_SignedInNavigator> createState() => _SignedInNavigatorState();
}

class _SignedInNavigatorState extends State<_SignedInNavigator> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) => NavigatorPopHandler<Object?>(
    onPopWithResult: (result) => _navigatorKey.currentState!.pop(result),
    child: Navigator(
      key: _navigatorKey,
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => MainDashboardScreen(user: widget.user),
      ),
    ),
  );
}

// -----------------------------------------------------------------------------
// MAIN DASHBOARD (FLASHCARDS SCANNING & UPLOAD)
// -----------------------------------------------------------------------------
class MainDashboardScreen extends StatefulWidget {
  final User user;

  const MainDashboardScreen({super.key, required this.user});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  bool _isProcessing = false;
  String _processingMessage = 'Finding the key ideas in your notes…';

  // 10MB Maximum File Size Constant
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10,485,760 bytes

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: NocturneTheme.background),
        ),
        backgroundColor: NocturneTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String get _geminiApiKey {
    return dotenv.isInitialized ? dotenv.env['GEMINI_API_KEY'] ?? '' : '';
  }

  String get _currentUserId {
    return widget.user.uid;
  }

  // ---------------------------------------------------------------------------
  // AI PROCESSING ENGINE (GEMINI 1.5 FLASH - EXCLUSIVELY FLASHCARDS & 10MB LIMIT)
  // ---------------------------------------------------------------------------
  Future<void> _processInputData({
    String? rawText,
    Uint8List? imageBytes,
    String? mimeType,
  }) async {
    if (!mounted || _isProcessing) return;
    final apiKey = _geminiApiKey;
    if (apiKey.isEmpty || apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      _showErrorSnackBar(
        'Flashcard creation is unavailable right now. Please try again later.',
      );
      return;
    }

    // FILE SIZE VALIDATION (10MB LIMIT)
    if (imageBytes != null && imageBytes.lengthInBytes > maxFileSizeBytes) {
      final sizeMB = (imageBytes.lengthInBytes / (1024 * 1024)).toStringAsFixed(
        1,
      );
      _showErrorSnackBar(
        'File exceeds the 10MB limit (Selected: ${sizeMB}MB). Please upload a smaller file.',
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingMessage = 'Turning your material into thoughtful flashcards…';
    });

    try {
      final result = await GeminiFlashcardService.generate(
        apiKey: apiKey,
        rawText: rawText,
        bytes: imageBytes,
        mimeType: mimeType,
      );

      final flashcards = result.cards
          .map((c) => Flashcard(question: c['question']!, answer: c['answer']!))
          .toList();

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultsScreen(
            title: result.title,
            flashcards: flashcards,
            userId: _currentUserId,
          ),
        ),
      );
    } catch (e) {
      _showErrorSnackBar(
        'We couldn’t create flashcards from this material. Check your connection or try a shorter passage.',
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // ACTION HANDLERS WITH 10MB FILE SIZE CHECK
  // ---------------------------------------------------------------------------
  Future<void> _pickImageFromCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        if (bytes.lengthInBytes > maxFileSizeBytes) {
          final sizeMB = (bytes.lengthInBytes / (1024 * 1024)).toStringAsFixed(
            1,
          );
          _showErrorSnackBar(
            'Captured image exceeds 10MB limit (${sizeMB}MB). Please try again.',
          );
          return;
        }
        final mime = photo.mimeType ?? 'image/jpeg';
        await _processInputData(imageBytes: bytes, mimeType: mime);
      }
    } catch (e) {
      _showErrorSnackBar("Camera error: $e");
    }
  }

  Future<void> _pickFileOrGallery() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'png', 'jpg', 'jpeg', 'webp', 'docx'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // 10MB File Size Limit Check
        if (file.size > maxFileSizeBytes) {
          final sizeMB = (file.size / (1024 * 1024)).toStringAsFixed(1);
          _showErrorSnackBar(
            'Selected file exceeds the 10MB limit (${sizeMB}MB). Please select a smaller file.',
          );
          return;
        }

        final extension = file.extension?.toLowerCase() ?? '';
        final bytes =
            file.bytes ??
            (file.path != null ? await File(file.path!).readAsBytes() : null);

        if (bytes == null) {
          _showErrorSnackBar("Could not read content from selected file.");
          return;
        }

        if (extension == 'docx') {
          final extracted = DocxTextExtractor.extract(bytes);
          if (extracted != null && extracted.isNotEmpty) {
            await _processInputData(rawText: extracted);
          } else {
            _showErrorSnackBar("Could not extract text from .docx file.");
          }
        } else if (extension == 'txt') {
          final textContent = utf8.decode(bytes, allowMalformed: true);
          if (textContent.trim().isNotEmpty) {
            await _processInputData(rawText: textContent);
          } else {
            _showErrorSnackBar("Selected text file is empty.");
          }
        } else {
          String? mime;
          if (extension == 'pdf') mime = 'application/pdf';
          if (['png', 'jpg', 'jpeg', 'webp'].contains(extension)) {
            mime = 'image/${extension == 'jpg' ? 'jpeg' : extension}';
          }
          await _processInputData(imageBytes: bytes, mimeType: mime);
        }
      }
    } catch (e) {
      _showErrorSnackBar("File picker error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.user.displayName ?? 'Curious mind';
    return DashboardView(
      displayName: displayName,
      avatar: UserAvatarWidget(
        photoUrl: widget.user.photoURL,
        displayName: displayName,
        radius: 17,
      ),
      onLibrary: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ProfileScreen(user: widget.user),
        ),
      ),
      onCamera: _pickImageFromCamera,
      onImport: _pickFileOrGallery,
      onGenerate: (text) => _processInputData(rawText: text),
      isProcessing: _isProcessing,
      processingMessage: _processingMessage,
    );
  }
}

// -----------------------------------------------------------------------------
// PROFILE PAGE & SAVED HISTORY/BOOKMARKS HUB
// -----------------------------------------------------------------------------
class ProfileScreen extends StatefulWidget {
  final User user;
  final Stream<List<ProcessedDocument>>? documents;
  const ProfileScreen({super.key, required this.user, this.documents});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _searchQuery = '';
  bool _bookmarksOnly = false;
  bool _isSigningOut = false;
  late Stream<List<ProcessedDocument>> _documents;

  @override
  void initState() {
    super.initState();
    _connectLibrary();
  }

  void _connectLibrary() {
    _documents =
        widget.documents ??
        FirebaseFirestore.instance
            .collection('user_documents')
            .where('userId', isEqualTo: widget.user.uid)
            .snapshots()
            .map(
              (snapshot) =>
                  snapshot.docs.map(ProcessedDocument.fromFirestore).toList(),
            );
  }

  Future<void> _toggleBookmark(ProcessedDocument document) async {
    try {
      await FirebaseFirestore.instance
          .collection('user_documents')
          .doc(document.id)
          .update({'isBookmarked': !document.isBookmarked});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Couldn’t update this bookmark. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    try {
      await FirebaseAuth.instance.signOut();
      // AuthGate clears this entire navigation stack.
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t sign out. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Your library'),
      actions: [
        IconButton(
          tooltip: 'Sign out',
          onPressed: _isSigningOut ? null : _signOut,
          icon: _isSigningOut
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout_rounded, size: 21),
        ),
        const SizedBox(width: 12),
      ],
    ),
    body: NightBackdrop(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      UserAvatarWidget(
                        photoUrl: widget.user.photoURL,
                        displayName: widget.user.displayName ?? 'You',
                        radius: 22,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.user.displayName ?? 'Your account',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (widget.user.email != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.user.email!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: NocturneTheme.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'YOUR PERSONAL ARCHIVE',
                    style: NocturneTheme.eyebrow,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Knowledge, collected.',
                    style: NocturneTheme.heading.copyWith(fontSize: 40),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Return to the ideas worth remembering.',
                    style: TextStyle(
                      color: NocturneTheme.muted,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 26),
                  TextField(
                    onChanged: (value) => setState(
                      () => _searchQuery = value.trim().toLowerCase(),
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Search your collection',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ChoiceChip(
                        label: const Text('All decks'),
                        selected: !_bookmarksOnly,
                        onSelected: (_) =>
                            setState(() => _bookmarksOnly = false),
                      ),
                      ChoiceChip(
                        label: const Text('Bookmarked'),
                        selected: _bookmarksOnly,
                        onSelected: (_) =>
                            setState(() => _bookmarksOnly = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  StreamBuilder<List<ProcessedDocument>>(
                    stream: _documents,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _libraryNotice(
                          'Your collection is out of reach',
                          'Check your connection and try loading it again.',
                          action: TextButton(
                            onPressed: () => setState(_connectLibrary),
                            child: const Text('Try again'),
                          ),
                        );
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }
                      final all = snapshot.data ?? [];
                      if (all.isEmpty) {
                        return _libraryNotice(
                          'Your collection starts here',
                          'Create a deck, then save it to keep your discoveries close.',
                          action: TextButton.icon(
                            onPressed: () => Navigator.maybePop(context),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Create your first deck'),
                          ),
                        );
                      }
                      final cards = all.fold<int>(
                        0,
                        (total, doc) => total + doc.flashcards.length,
                      );
                      final filtered =
                          all.where((doc) {
                            if (_bookmarksOnly && !doc.isBookmarked) {
                              return false;
                            }
                            return doc.title.toLowerCase().contains(
                                  _searchQuery,
                                ) ||
                                doc.flashcards.any(
                                  (card) =>
                                      card.question.toLowerCase().contains(
                                        _searchQuery,
                                      ) ||
                                      card.answer.toLowerCase().contains(
                                        _searchQuery,
                                      ),
                                );
                          }).toList()..sort(
                            (a, b) => b.createdAt.compareTo(a.createdAt),
                          );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${all.length} saved decks  ·  $cards flashcards',
                            style: const TextStyle(
                              color: NocturneTheme.muted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (filtered.isEmpty)
                            _libraryNotice(
                              'No discoveries here yet',
                              _bookmarksOnly
                                  ? 'Bookmark a deck to find it here.'
                                  : 'Try another title or a word from your cards.',
                            )
                          else
                            ...filtered.map(_deckTile),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _libraryNotice(String title, String description, {Widget? action}) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: NocturneTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: NocturneTheme.border),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.collections_bookmark_outlined,
              size: 32,
              color: NocturneTheme.accent,
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: NocturneTheme.heading.copyWith(fontSize: 28),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: NocturneTheme.muted,
                fontSize: 13,
                height: 1.6,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 16), action],
          ],
        ),
      );

  Widget _deckTile(ProcessedDocument document) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 12,
        ),
        leading: const Icon(Icons.style_outlined, color: NocturneTheme.accent),
        title: Text(
          document.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${document.flashcards.length} ${document.flashcards.length == 1 ? 'card' : 'cards'} · ${document.createdAt.day}/${document.createdAt.month}/${document.createdAt.year}',
            style: const TextStyle(color: NocturneTheme.muted, fontSize: 12),
          ),
        ),
        trailing: IconButton(
          tooltip: document.isBookmarked ? 'Remove bookmark' : 'Bookmark deck',
          icon: Icon(
            document.isBookmarked
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            color: document.isBookmarked
                ? NocturneTheme.gold
                : NocturneTheme.muted,
          ),
          onPressed: () => _toggleBookmark(document),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ResultsScreen(
              title: document.title,
              flashcards: document.flashcards,
              userId: widget.user.uid,
              isSaved: true,
            ),
          ),
        ),
      ),
    ),
  );
}

// -----------------------------------------------------------------------------
// HELPER WIDGETS
// -----------------------------------------------------------------------------
class UserAvatarWidget extends StatelessWidget {
  final String? photoUrl;
  final String displayName;
  final double radius;

  const UserAvatarWidget({
    super.key,
    required this.photoUrl,
    required this.displayName,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final initial = displayName.trim().isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : 'U';

    if (photoUrl != null && photoUrl!.trim().isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: NocturneTheme.accent,
        child: ClipOval(
          child: Image.network(
            photoUrl!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: radius * 2,
                height: radius * 2,
                color: NocturneTheme.accent,
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: NocturneTheme.background,
                    fontWeight: FontWeight.bold,
                    fontSize: radius * 0.7,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: NocturneTheme.accent,
      child: Text(
        initial,
        style: TextStyle(
          color: NocturneTheme.background,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// RESULTS SCREEN (EXCLUSIVELY FLASHCARDS)
// -----------------------------------------------------------------------------
class ResultsScreen extends StatefulWidget {
  final String title;
  final List<Flashcard> flashcards;
  final String userId;
  final bool isSaved;

  const ResultsScreen({
    super.key,
    required this.title,
    required this.flashcards,
    required this.userId,
    this.isSaved = false,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late bool _alreadySaved;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _alreadySaved = widget.isSaved;
  }

  Future<void> _saveToFirestore() async {
    if (_alreadySaved || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('user_documents').add({
        'title': widget.title,
        'userId': widget.userId,
        'createdAt': FieldValue.serverTimestamp(),
        'flashcards': widget.flashcards.map((c) => c.toJson()).toList(),
        'isBookmarked': false,
      });

      if (!mounted) return;
      setState(() => _alreadySaved = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Saved. Your discovery is waiting in your library.',
              style: TextStyle(color: NocturneTheme.background),
            ),
            backgroundColor: NocturneTheme.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Couldn’t save this deck. Please try again.',
              style: TextStyle(color: NocturneTheme.background),
            ),
            backgroundColor: NocturneTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Study deck')),
    body: NightBackdrop(
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: Text(
                widget.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: NocturneTheme.heading.copyWith(
                  fontSize: 34,
                  height: 1.1,
                ),
              ),
            ),
            Expanded(child: _FlashcardsDeckView(flashcards: widget.flashcards)),
          ],
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
        child: ElevatedButton.icon(
          onPressed: _alreadySaved || _isSaving ? null : _saveToFirestore,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  _alreadySaved
                      ? Icons.check_rounded
                      : Icons.bookmark_add_outlined,
                  size: 20,
                ),
          label: Text(
            _isSaving
                ? 'Saving…'
                : _alreadySaved
                ? 'Saved to your library'
                : 'Save to library',
          ),
        ),
      ),
    ),
  );
}

// -----------------------------------------------------------------------------
// INTERACTIVE FLASHCARD DECK (GRID VS SINGLE VIEW MODE)
// -----------------------------------------------------------------------------
class _FlashcardsDeckView extends StatefulWidget {
  final List<Flashcard> flashcards;
  const _FlashcardsDeckView({required this.flashcards});

  @override
  State<_FlashcardsDeckView> createState() => _FlashcardsDeckViewState();
}

class _FlashcardsDeckViewState extends State<_FlashcardsDeckView> {
  bool _isSingleView = true;
  int _currentIndex = 0;
  final Set<int> _revealed = {};

  @override
  Widget build(BuildContext context) {
    if (widget.flashcards.isEmpty) {
      return const Center(child: Text('No flashcards in this deck yet.'));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Wrap(
            spacing: 20,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${widget.flashcards.length} ideas to explore',
                style: const TextStyle(
                  color: NocturneTheme.muted,
                  fontSize: 12,
                ),
              ),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Focus'),
                    icon: Icon(Icons.crop_portrait_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Grid'),
                    icon: Icon(Icons.grid_view_rounded, size: 16),
                  ),
                ],
                selected: {_isSingleView},
                onSelectionChanged: (selection) =>
                    setState(() => _isSingleView = selection.first),
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isSingleView
              ? SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Column(
                        children: [
                          _card(_currentIndex, focused: true),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton.filledTonal(
                                tooltip: 'Previous card',
                                onPressed: _currentIndex == 0
                                    ? null
                                    : () => setState(() => _currentIndex--),
                                icon: const Icon(
                                  Icons.arrow_back_rounded,
                                  size: 20,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Text(
                                  '${_currentIndex + 1} / ${widget.flashcards.length}',
                                  style: const TextStyle(
                                    color: NocturneTheme.muted,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              IconButton.filledTonal(
                                tooltip: 'Next card',
                                onPressed:
                                    _currentIndex ==
                                        widget.flashcards.length - 1
                                    ? null
                                    : () => setState(() => _currentIndex++),
                                icon: const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = (constraints.maxWidth / 300).floor().clamp(
                      1,
                      4,
                    );
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisExtent: 280,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: widget.flashcards.length,
                      itemBuilder: (context, index) => _card(index),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _card(int index, {bool focused = false}) {
    final revealed = _revealed.contains(index);
    final card = widget.flashcards[index];
    final content = revealed ? card.answer : card.question;
    final accent = revealed ? NocturneTheme.gold : NocturneTheme.accent;
    return Semantics(
      button: true,
      label: '${revealed ? 'Answer' : 'Question'} ${index + 1}. $content',
      hint: revealed ? 'Show question' : 'Reveal answer',
      excludeSemantics: true,
      child: Material(
        color: NocturneTheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: accent.withValues(alpha: 0.35)),
        ),
        child: InkWell(
          onTap: () => setState(() {
            revealed ? _revealed.remove(index) : _revealed.add(index);
          }),
          child: Padding(
            padding: EdgeInsets.all(focused ? 28 : 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        revealed ? 'THE DISCOVERY' : 'A MOMENT TO THINK',
                        style: NocturneTheme.eyebrow.copyWith(
                          color: accent,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${index + 1}'.padLeft(2, '0'),
                      style: TextStyle(color: accent, fontSize: 12),
                    ),
                  ],
                ),
                if (focused)
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 230),
                    child: Center(
                      child: _cardText(content, index, revealed, true),
                    ),
                  )
                else
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: _cardText(content, index, revealed, false),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Divider(color: accent.withValues(alpha: 0.15)),
                const SizedBox(height: 8),
                Text(
                  revealed
                      ? 'Tap to revisit the question'
                      : 'Tap to reveal the answer',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: NocturneTheme.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cardText(String content, int index, bool revealed, bool focused) =>
      AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        child: Text(
          content,
          key: ValueKey('$index-$revealed'),
          textAlign: TextAlign.center,
          style: focused
              ? NocturneTheme.heading.copyWith(fontSize: 30, height: 1.3)
              : const TextStyle(fontSize: 16, height: 1.6),
        ),
      );
}
