import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';

import 'firebase_options.dart';
import 'gemini_flashcard_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
// CLEAN MODERN DARK MODE THEME & PALETTE
// -----------------------------------------------------------------------------
class CleanDarkTheme {
  static const Color bgNavy = Color(0xFF0D1117);
  static const Color surfaceCard = Color(0xFF161B22);
  static const Color surfaceBorder = Color(0xFF30363D);
  static const Color cyanAccent = Color(0xFF00E5FF);
  static const Color goldAccent = Color(0xFFFFC107);
  static const Color textPrimary = Color(0xFFF0F6FC);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color errorRed = Color(0xFFF85149);

  static ThemeData get theme {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: bgNavy,
      primaryColor: cyanAccent,
      colorScheme: const ColorScheme.dark(
        primary: cyanAccent,
        surface: surfaceCard,
        error: errorRed,
      ),
      textTheme: baseTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: bgNavy,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: cyanAccent),
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: surfaceBorder, width: 1.0),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cyanAccent,
          foregroundColor: bgNavy,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: surfaceBorder, width: 1.0),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: cyanAccent,
        foregroundColor: bgNavy,
        elevation: 4,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// CUSTOM PAINTER: SUBTLE CIRCUIT & DOT PATTERN BACKGROUND
// -----------------------------------------------------------------------------
class CircuitPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = CleanDarkTheme.cyanAccent.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = CleanDarkTheme.cyanAccent.withValues(alpha: 0.04)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const double spacing = 36.0;

    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }

    final random = Random(42);
    for (int i = 0; i < 18; i++) {
      final startX = (random.nextInt((size.width / spacing).floor()) * spacing) + spacing / 2;
      final startY = (random.nextInt((size.height / spacing).floor()) * spacing) + spacing / 2;

      final path = Path()..moveTo(startX, startY);
      double currentX = startX;
      double currentY = startY;

      for (int step = 0; step < 3; step++) {
        if (random.nextBool()) {
          currentX += (random.nextBool() ? spacing : -spacing);
        } else {
          currentY += (random.nextBool() ? spacing : -spacing);
        }
        path.lineTo(currentX, currentY);
      }
      canvas.drawPath(path, linePaint);
      canvas.drawCircle(Offset(currentX, currentY), 2.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -----------------------------------------------------------------------------
// DATA MODELS (FLASHCARDS ONLY)
// -----------------------------------------------------------------------------
class Flashcard {
  final String question;
  final String answer;

  Flashcard({required this.question, required this.answer});

  Map<String, dynamic> toJson() => {
        'question': question,
        'answer': answer,
      };

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
      theme: CleanDarkTheme.theme,
      home: const AuthGate(),
    );
  }
}

// -----------------------------------------------------------------------------
// AUTH GATE & BYPASS
// -----------------------------------------------------------------------------
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _autoSignInAnonymous();
  }

  Future<void> _autoSignInAnonymous() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'configuration-not-found') {
        debugPrint("Anonymous Auth note: not configured in Firebase Console.");
      } else {
        debugPrint("Auto sign-in note: ${e.message}");
      }
    } catch (e) {
      debugPrint("Auto sign-in note: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        return MainDashboardScreen(user: snapshot.data);
      },
    );
  }
}

// -----------------------------------------------------------------------------
// MAIN DASHBOARD (FLASHCARDS SCANNING & UPLOAD)
// -----------------------------------------------------------------------------
class MainDashboardScreen extends StatefulWidget {
  final User? user;

  const MainDashboardScreen({super.key, this.user});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  bool _isProcessing = false;
  String _processingMessage = "Scanning Document with Gemini AI...";

  // 10MB Maximum File Size Constant
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10,485,760 bytes

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: CleanDarkTheme.errorRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String get _geminiApiKey {
    return dotenv.env['GEMINI_API_KEY'] ?? '';
  }

  String get _currentUserId {
    return widget.user?.uid ?? 'guest_user';
  }

  Future<void> _signInWithGoogle() async {
    try {
      final googleClientId = dotenv.env['GOOGLE_CLIENT_ID'];
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: kIsWeb ? googleClientId : null,
        serverClientId: kIsWeb ? null : googleClientId,
      );
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed in successfully!'),
            backgroundColor: CleanDarkTheme.cyanAccent,
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar("Sign-In error: ${e.toString()}");
    }
  }

  // ---------------------------------------------------------------------------
  // AI PROCESSING ENGINE (GEMINI 1.5 FLASH - EXCLUSIVELY FLASHCARDS & 10MB LIMIT)
  // ---------------------------------------------------------------------------
  Future<void> _processInputData({
    String? rawText,
    Uint8List? imageBytes,
    String? mimeType,
  }) async {
    final apiKey = _geminiApiKey;
    if (apiKey.isEmpty || apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      _showErrorSnackBar(
          'Please configure a valid GEMINI_API_KEY in your .env file!');
      return;
    }

    // FILE SIZE VALIDATION (10MB LIMIT)
    if (imageBytes != null && imageBytes.lengthInBytes > maxFileSizeBytes) {
      final sizeMB = (imageBytes.lengthInBytes / (1024 * 1024)).toStringAsFixed(1);
      _showErrorSnackBar(
          'File exceeds the 10MB limit (Selected: ${sizeMB}MB). Please upload a smaller file.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingMessage = "Extracting Concepts & Synthesizing Flashcards...";
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
          "Processing Error: ${e.toString().replaceFirst('Exception: ', '')}");
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
          final sizeMB = (bytes.lengthInBytes / (1024 * 1024)).toStringAsFixed(1);
          _showErrorSnackBar(
              'Captured image exceeds 10MB limit (${sizeMB}MB). Please try again.');
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
              'Selected file exceeds the 10MB limit (${sizeMB}MB). Please select a smaller file.');
          return;
        }

        final extension = file.extension?.toLowerCase() ?? '';
        final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);

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

  Future<void> _pasteClipboard() async {
    try {
      final ClipboardData? data =
          await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null && data.text!.trim().isNotEmpty) {
        await _processInputData(rawText: data.text);
      } else {
        _showErrorSnackBar("Clipboard is empty or contains no text!");
      }
    } catch (e) {
      _showErrorSnackBar("Clipboard paste error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSignedIn = widget.user != null && !widget.user!.isAnonymous;
    final photoUrl = widget.user?.photoURL;
    final displayName = widget.user?.displayName ?? widget.user?.email ?? 'User';

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: CircuitPatternPainter(),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // -------------------------------------------------------------
                // TOP BAR WITH APP TITLE & PROFILE AVATAR
                // -------------------------------------------------------------
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: CleanDarkTheme.surfaceBorder, width: 1.0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: CleanDarkTheme.surfaceCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: CleanDarkTheme.surfaceBorder),
                        ),
                        child: const Icon(
                          Icons.content_paste_rounded,
                          size: 20,
                          color: CleanDarkTheme.cyanAccent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Just Paste',
                        style: GoogleFonts.inter(
                          color: CleanDarkTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),

                      if (!isSignedIn) ...[
                        OutlinedButton(
                          onPressed: _signInWithGoogle,
                          child: const Text('Sign In'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _signInWithGoogle,
                          child: const Text('Get Started'),
                        ),
                      ] else ...[
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileScreen(user: widget.user!),
                              ),
                            );
                          },
                          child: Tooltip(
                            message: 'View Profile & Saved Library',
                            child: UserAvatarWidget(
                              photoUrl: photoUrl,
                              displayName: displayName,
                              radius: 18,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),

                        // STEP INDICATOR PILL (AI FLASHCARDS ONLY)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: CleanDarkTheme.surfaceCard,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: CleanDarkTheme.surfaceBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: CleanDarkTheme.cyanAccent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '1',
                                  style: GoogleFonts.inter(
                                    color: CleanDarkTheme.bgNavy,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Paste or Upload File',
                                style: GoogleFonts.inter(
                                  color: CleanDarkTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.arrow_forward_rounded,
                                  color: CleanDarkTheme.textSecondary, size: 16),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: CleanDarkTheme.surfaceBorder,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '2',
                                  style: GoogleFonts.inter(
                                    color: CleanDarkTheme.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'AI Flashcards',
                                style: GoogleFonts.inter(
                                  color: CleanDarkTheme.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // MAIN DROPZONE CONTAINER (10MB MAX NOTICE)
                        GestureDetector(
                          onTap: _pickFileOrGallery,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 24),
                            decoration: BoxDecoration(
                              color: CleanDarkTheme.surfaceCard,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: CleanDarkTheme.cyanAccent.withValues(alpha: 0.6),
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: CleanDarkTheme.bgNavy,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: CleanDarkTheme.surfaceBorder),
                                  ),
                                  child: const Icon(
                                    Icons.cloud_upload_outlined,
                                    size: 40,
                                    color: CleanDarkTheme.cyanAccent,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Tap or Drop Document Here',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    color: CleanDarkTheme.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Upload screenshots, photos, PDF, DOCX, TXT, or paste clipboard (Max 10MB)',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    color: CleanDarkTheme.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    _CleanChip(label: 'PDF'),
                                    _CleanChip(label: 'DOCX'),
                                    _CleanChip(label: 'TXT'),
                                    _CleanChip(label: 'PNG'),
                                    _CleanChip(label: 'JPG'),
                                    _CleanChip(label: 'WEBP'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // FLAT BOTTOM ACTION CARDS
                        Row(
                          children: [
                            Expanded(
                              child: _FlatActionCard(
                                icon: Icons.camera_alt_outlined,
                                label: 'Camera',
                                onTap: _pickImageFromCamera,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _FlatActionCard(
                                icon: Icons.folder_open_outlined,
                                label: 'Gallery/Doc',
                                onTap: _pickFileOrGallery,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _FlatActionCard(
                                icon: Icons.content_paste_outlined,
                                label: 'Clipboard',
                                onTap: _pasteClipboard,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // LOADING OVERLAY
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.8),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: CleanDarkTheme.surfaceCard,
                        shape: BoxShape.circle,
                      ),
                      child: const CircularProgressIndicator(
                        color: CleanDarkTheme.cyanAccent,
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _processingMessage,
                      style: GoogleFonts.inter(
                        color: CleanDarkTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Powered by Gemini AI Engine',
                      style: GoogleFonts.inter(
                        color: CleanDarkTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PROFILE PAGE & SAVED HISTORY/BOOKMARKS HUB
// -----------------------------------------------------------------------------
class ProfileScreen extends StatefulWidget {
  final User user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _searchQuery = '';
  int _selectedTab = 0; // 0: All Scans, 1: Bookmarked Only

  void _toggleBookmark(String docId, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('user_documents')
          .doc(docId)
          .update({'isBookmarked': !currentStatus});
    } catch (e) {
      debugPrint("Toggle bookmark error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = widget.user.photoURL;
    final displayName = widget.user.displayName ?? widget.user.email ?? 'User';
    final email = widget.user.email ?? (widget.user.isAnonymous ? 'Guest User' : 'No email');

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 10.0, bottom: 10.0),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Tooltip(
              message: 'Back to Dashboard',
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: CleanDarkTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: CleanDarkTheme.surfaceBorder),
                ),
                child: const Icon(
                  Icons.content_paste_rounded,
                  size: 18,
                  color: CleanDarkTheme.cyanAccent,
                ),
              ),
            ),
          ),
        ),
        title: const Text('Account & Saved Library'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: CircuitPatternPainter(),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // BACK TO DASHBOARD BUTTON
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16, color: CleanDarkTheme.textSecondary),
                    label: Text(
                      'Back to Dashboard',
                      style: GoogleFonts.inter(
                        color: CleanDarkTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // USER PROFILE CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: CleanDarkTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: CleanDarkTheme.surfaceBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            UserAvatarWidget(
                              photoUrl: photoUrl,
                              displayName: displayName,
                              radius: 30,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          displayName,
                                          style: GoogleFonts.inter(
                                            color: CleanDarkTheme.textPrimary,
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: CleanDarkTheme.cyanAccent.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: CleanDarkTheme.cyanAccent.withValues(alpha: 0.4)),
                                        ),
                                        child: Text(
                                          'FREE',
                                          style: GoogleFonts.inter(
                                            color: CleanDarkTheme.cyanAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    email,
                                    style: GoogleFonts.inter(
                                      color: CleanDarkTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: CleanDarkTheme.textSecondary,
                                side: const BorderSide(color: CleanDarkTheme.surfaceBorder),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                              onPressed: () async {
                                await FirebaseAuth.instance.signOut();
                                if (context.mounted) Navigator.pop(context);
                              },
                              icon: const Icon(Icons.logout_rounded, size: 16),
                              label: const Text('Sign out', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // USAGE & ANALYTICS SECTION
                  Text(
                    'USAGE & CONVERSIONS',
                    style: GoogleFonts.inter(
                      color: CleanDarkTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 10),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('user_documents')
                        .where('userId', isEqualTo: widget.user.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final totalScans = snapshot.data?.docs.length ?? 0;
                      final bookmarkedScans = snapshot.data?.docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>? ?? {};
                            return data['isBookmarked'] as bool? ?? false;
                          }).length ??
                          0;

                      int totalCards = 0;
                      if (snapshot.hasData) {
                        for (var doc in snapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>? ?? {};
                          final cards = data['flashcards'] as List? ?? [];
                          totalCards += cards.length;
                        }
                      }

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  title: 'Total Scans',
                                  value: '$totalScans',
                                  icon: Icons.auto_awesome,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  title: 'Bookmarked',
                                  value: '$bookmarkedScans',
                                  icon: Icons.star_rounded,
                                  color: CleanDarkTheme.goldAccent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  title: 'Flashcards Generated',
                                  value: '$totalCards',
                                  icon: Icons.style_rounded,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  title: 'Free Conversions',
                                  value: 'Unlimited',
                                  icon: Icons.all_inclusive_rounded,
                                  color: CleanDarkTheme.cyanAccent,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // SAVED FLASHCARD DECKS HEADER
                  Text(
                    'SAVED FLASHCARD DECKS',
                    style: GoogleFonts.inter(
                      color: CleanDarkTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // SEARCH BAR
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                    style: GoogleFonts.inter(color: CleanDarkTheme.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search saved flashcard decks...',
                      hintStyle: GoogleFonts.inter(color: CleanDarkTheme.textSecondary, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: CleanDarkTheme.textSecondary, size: 20),
                      filled: true,
                      fillColor: CleanDarkTheme.surfaceCard,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: CleanDarkTheme.surfaceBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: CleanDarkTheme.surfaceBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: CleanDarkTheme.cyanAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // SUB TABS: ALL SCANS vs BOOKMARKED
                  Row(
                    children: [
                      _FilterTabButton(
                        label: 'All Decks',
                        isSelected: _selectedTab == 0,
                        onTap: () => setState(() => _selectedTab = 0),
                      ),
                      const SizedBox(width: 8),
                      _FilterTabButton(
                        label: '⭐ Bookmarked',
                        isSelected: _selectedTab == 1,
                        onTap: () => setState(() => _selectedTab = 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // FIRESTORE HISTORY STREAM WITH SKELETON LOADERS
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('user_documents')
                        .where('userId', isEqualTo: widget.user.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: 4,
                          itemBuilder: (context, index) => const _SkeletonCardLoader(),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: CleanDarkTheme.surfaceCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: CleanDarkTheme.surfaceBorder),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.style_outlined, size: 40, color: CleanDarkTheme.textSecondary),
                              const SizedBox(height: 12),
                              Text(
                                'No saved flashcard decks found',
                                style: GoogleFonts.inter(
                                  color: CleanDarkTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Flashcard decks you generate will appear here in real-time.',
                                style: GoogleFonts.inter(
                                  color: CleanDarkTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      var docs = snapshot.data!.docs.map((d) => ProcessedDocument.fromFirestore(d)).toList();

                      if (_selectedTab == 1) {
                        docs = docs.where((d) => d.isBookmarked).toList();
                      }

                      if (_searchQuery.isNotEmpty) {
                        docs = docs.where((d) {
                          final titleMatch = d.title.toLowerCase().contains(_searchQuery);
                          final cardMatch = d.flashcards.any((c) =>
                              c.question.toLowerCase().contains(_searchQuery) ||
                              c.answer.toLowerCase().contains(_searchQuery));
                          return titleMatch || cardMatch;
                        }).toList();
                      }

                      if (docs.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            'No flashcard decks matching search/filter.',
                            style: GoogleFonts.inter(color: CleanDarkTheme.textSecondary),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final docData = docs[index];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: CleanDarkTheme.bgNavy,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.style_rounded,
                                  color: CleanDarkTheme.cyanAccent,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                docData.title,
                                style: GoogleFonts.inter(
                                  color: CleanDarkTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${docData.flashcards.length} Flashcards',
                                style: GoogleFonts.inter(
                                  color: CleanDarkTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: docData.isBookmarked ? 'Remove Bookmark' : 'Bookmark',
                                    icon: Icon(
                                      docData.isBookmarked ? Icons.star_rounded : Icons.star_outline_rounded,
                                      color: docData.isBookmarked
                                          ? CleanDarkTheme.goldAccent
                                          : CleanDarkTheme.textSecondary,
                                    ),
                                    onPressed: () => _toggleBookmark(docData.id, docData.isBookmarked),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: CleanDarkTheme.cyanAccent,
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ResultsScreen(
                                      title: docData.title,
                                      flashcards: docData.flashcards,
                                      userId: widget.user.uid,
                                      isSaved: true,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
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
        backgroundColor: CleanDarkTheme.cyanAccent,
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
                color: CleanDarkTheme.cyanAccent,
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: GoogleFonts.inter(
                    color: CleanDarkTheme.bgNavy,
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
      backgroundColor: CleanDarkTheme.cyanAccent,
      child: Text(
        initial,
        style: GoogleFonts.inter(
          color: CleanDarkTheme.bgNavy,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.color = CleanDarkTheme.cyanAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: CleanDarkTheme.bgNavy,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CleanDarkTheme.surfaceBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: CleanDarkTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: CleanDarkTheme.textSecondary,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterTabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterTabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? CleanDarkTheme.cyanAccent : CleanDarkTheme.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? CleanDarkTheme.cyanAccent : CleanDarkTheme.surfaceBorder,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? CleanDarkTheme.bgNavy : CleanDarkTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _SkeletonCardLoader extends StatelessWidget {
  const _SkeletonCardLoader();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: CleanDarkTheme.surfaceCard,
      highlightColor: CleanDarkTheme.surfaceBorder,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Container(
          height: 64,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 140,
                      height: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 90,
                      height: 10,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CleanChip extends StatelessWidget {
  final String label;

  const _CleanChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: CleanDarkTheme.bgNavy,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: CleanDarkTheme.surfaceBorder),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: CleanDarkTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _FlatActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FlatActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: CleanDarkTheme.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CleanDarkTheme.surfaceBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: CleanDarkTheme.cyanAccent, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: CleanDarkTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
    if (_alreadySaved) return;

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('user_documents').add({
        'title': widget.title,
        'userId': widget.userId,
        'createdAt': FieldValue.serverTimestamp(),
        'flashcards': widget.flashcards.map((c) => c.toJson()).toList(),
        'isBookmarked': false,
      });

      setState(() => _alreadySaved = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Flashcard deck saved to your cloud library!'),
            backgroundColor: CleanDarkTheme.cyanAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save error: $e'),
            backgroundColor: CleanDarkTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 10.0, bottom: 10.0),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Tooltip(
              message: 'Back to Dashboard',
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: CleanDarkTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: CleanDarkTheme.surfaceBorder),
                ),
                child: const Icon(
                  Icons.content_paste_rounded,
                  size: 18,
                  color: CleanDarkTheme.cyanAccent,
                ),
              ),
            ),
          ),
        ),
        title: Text(widget.title),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20.0, top: 12.0),
            child: TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 16, color: CleanDarkTheme.textSecondary),
              label: Text(
                'Back to Dashboard',
                style: GoogleFonts.inter(
                  color: CleanDarkTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Expanded(
            child: _FlashcardsDeckView(flashcards: widget.flashcards),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _alreadySaved ? null : _saveToFirestore,
        backgroundColor:
            _alreadySaved ? CleanDarkTheme.surfaceBorder : CleanDarkTheme.cyanAccent,
        icon: _isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: CleanDarkTheme.bgNavy,
                ),
              )
            : Icon(
                _alreadySaved ? Icons.check_circle : Icons.bookmark_add_rounded,
                color: CleanDarkTheme.bgNavy,
              ),
        label: Text(
          _alreadySaved ? 'Saved to Cloud' : 'Save Deck',
          style: GoogleFonts.inter(
            color: CleanDarkTheme.bgNavy,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
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
  bool _isSingleView = false;
  int _currentIndex = 0;
  bool _singleShowAnswer = false;
  final Set<int> _flippedGridIndices = {};

  @override
  Widget build(BuildContext context) {
    if (widget.flashcards.isEmpty) {
      return const Center(
        child: Text(
          'No flashcards generated for this content.',
          style: TextStyle(color: CleanDarkTheme.textSecondary),
        ),
      );
    }

    return Column(
      children: [
        // HEADER TOOLBAR (CARDS COUNT & VIEW TOGGLE)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${widget.flashcards.length} cards generated',
                style: GoogleFonts.inter(
                  color: CleanDarkTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),

              // VIEW TOGGLE PILL: GRID | SINGLE
              Container(
                decoration: BoxDecoration(
                  color: CleanDarkTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: CleanDarkTheme.surfaceBorder),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _isSingleView = false),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: !_isSingleView ? CleanDarkTheme.surfaceBorder : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Grid',
                          style: GoogleFonts.inter(
                            color: !_isSingleView ? CleanDarkTheme.textPrimary : CleanDarkTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _isSingleView = true),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isSingleView ? CleanDarkTheme.surfaceBorder : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Single',
                          style: GoogleFonts.inter(
                            color: _isSingleView ? CleanDarkTheme.textPrimary : CleanDarkTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // MAIN CONTENT (GRID VIEW OR SINGLE VIEW)
        Expanded(
          child: _isSingleView ? _buildSingleView() : _buildGridView(),
        ),
      ],
    );
  }

  // GRID VIEW (COMPACT BALANCED CARDS WITH FLIP ANIMATION & NON-BLOCKING BOTTOM PADDING)
  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 90),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 360,
        mainAxisExtent: 220,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: widget.flashcards.length,
      itemBuilder: (context, index) {
        final card = widget.flashcards[index];
        final isFlipped = _flippedGridIndices.contains(index);

        return GestureDetector(
          onTap: () {
            setState(() {
              if (isFlipped) {
                _flippedGridIndices.remove(index);
              } else {
                _flippedGridIndices.add(index);
              }
            });
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              final rotate = Tween(begin: pi, end: 0.0).animate(animation);
              return AnimatedBuilder(
                animation: rotate,
                child: child,
                builder: (context, widgetChild) {
                  final isUnder =
                      (ValueKey(isFlipped) != widgetChild?.key);
                  var tilt = ((animation.value - 0.5).abs() - 0.5) * 0.003;
                  tilt *= isUnder ? -1.0 : 1.0;
                  final value = isUnder
                      ? min(rotate.value, pi / 2)
                      : rotate.value;
                  return Transform(
                    transform: Matrix4.rotationY(value)..setEntry(3, 2, tilt),
                    alignment: Alignment.center,
                    child: widgetChild,
                  );
                },
              );
            },
            child: Container(
              key: ValueKey(isFlipped),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: CleanDarkTheme.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isFlipped ? CleanDarkTheme.goldAccent : CleanDarkTheme.surfaceBorder,
                  width: 1.2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isFlipped ? 'ANSWER' : 'QUESTION',
                        style: GoogleFonts.inter(
                          color: isFlipped ? CleanDarkTheme.goldAccent : CleanDarkTheme.cyanAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        '#${index + 1}',
                        style: GoogleFonts.inter(
                          color: CleanDarkTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Text(
                          isFlipped ? card.answer : card.question,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: CleanDarkTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Click to flip',
                        style: GoogleFonts.inter(
                          color: CleanDarkTheme.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // SINGLE VIEW (LARGER ENLARGED CARD IN CENTER WITH 3D FLIP ANIMATION)
  Widget _buildSingleView() {
    final card = widget.flashcards[_currentIndex];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => setState(() => _singleShowAnswer = !_singleShowAnswer),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  final rotate = Tween(begin: pi, end: 0.0).animate(animation);
                  return AnimatedBuilder(
                    animation: rotate,
                    child: child,
                    builder: (context, widgetChild) {
                      final isUnder =
                          (ValueKey(_singleShowAnswer) != widgetChild?.key);
                      var tilt = ((animation.value - 0.5).abs() - 0.5) * 0.003;
                      tilt *= isUnder ? -1.0 : 1.0;
                      final value = isUnder
                          ? min(rotate.value, pi / 2)
                          : rotate.value;
                      return Transform(
                        transform: Matrix4.rotationY(value)..setEntry(3, 2, tilt),
                        alignment: Alignment.center,
                        child: widgetChild,
                      );
                    },
                  );
                },
                child: Container(
                  key: ValueKey(_singleShowAnswer),
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 580, minHeight: 260),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: CleanDarkTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: CleanDarkTheme.cyanAccent.withValues(alpha: 0.8),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _singleShowAnswer ? 'ANSWER' : 'QUESTION',
                        style: GoogleFonts.inter(
                          color: CleanDarkTheme.cyanAccent,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _singleShowAnswer ? card.answer : card.question,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: CleanDarkTheme.textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Click to flip',
                        style: GoogleFonts.inter(
                          color: CleanDarkTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // NAV CONTROLS: ←  1 / N  →
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: CleanDarkTheme.surfaceCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: CleanDarkTheme.surfaceBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.arrow_back_ios_rounded),
                    color: _currentIndex > 0 ? CleanDarkTheme.cyanAccent : CleanDarkTheme.textSecondary,
                    onPressed: _currentIndex > 0
                        ? () => setState(() {
                              _currentIndex--;
                              _singleShowAnswer = false;
                            })
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${_currentIndex + 1} / ${widget.flashcards.length}',
                    style: GoogleFonts.inter(
                      color: CleanDarkTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.arrow_forward_ios_rounded),
                    color: _currentIndex < widget.flashcards.length - 1
                        ? CleanDarkTheme.cyanAccent
                        : CleanDarkTheme.textSecondary,
                    onPressed: _currentIndex < widget.flashcards.length - 1
                        ? () => setState(() {
                              _currentIndex++;
                              _singleShowAnswer = false;
                            })
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
