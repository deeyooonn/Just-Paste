import 'dart:async';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Plain-data result so this file never has to import main.dart.
class GeneratedFlashcards {
  final String title;
  final List<Map<String, String>> cards; // [{question, answer}, ...]
  final bool wasRepaired; // true if the output was cut off and salvaged
  const GeneratedFlashcards(this.title, this.cards, {this.wasRepaired = false});
}

class GeminiFlashcardService {
  GeminiFlashcardService._();

  // ---------------------------------------------------------------------------
  // MODEL CONFIG - the ONE place to change the model.
  // 'gemini-1.5-flash' was shut down by Google and returns 404 for every key.
  // ---------------------------------------------------------------------------
  static const String primaryModel = 'gemini-3.8-flash';
  static const List<String> fallbackModels = [
    'gemini-3.5-flash',
    'gemini-3.5-flash-lite',
  ];

  static const int maxOutputTokens = 8192;
  static const double temperature = 0.2;
  static const Duration requestTimeout = Duration(seconds: 120);

  // MIME types Gemini accepts as inlineData for this app.
  static const Set<String> _inlineMimeTypes = {
    'application/pdf',
    'image/png',
    'image/jpeg',
    'image/webp',
    'image/heic',
    'image/heif',
  };

  static const String _systemPrompt = '''
You are an expert educational assistant. Read the provided material and write study flashcards covering its key concepts, definitions, facts and relationships.

Rules:
- Write at most 40 flashcards. Prioritise the most important material.
- Keep every answer concise (1-3 sentences) so the whole response stays short.
- Output ONLY a JSON object, no markdown, no commentary, in this shape:
{"title": "Short Summary Title", "flashcards": [{"question": "...", "answer": "..."}]}
''';

  static final Schema _schema = Schema.object(
    properties: {
      'title': Schema.string(description: 'Short summary title'),
      'flashcards': Schema.array(
        items: Schema.object(
          properties: {
            'question': Schema.string(description: 'Question text'),
            'answer': Schema.string(description: 'Answer text'),
          },
          requiredProperties: ['question', 'answer'],
        ),
      ),
    },
    requiredProperties: ['title', 'flashcards'],
  );

  // ---------------------------------------------------------------------------
  // PUBLIC ENTRY POINT
  // ---------------------------------------------------------------------------
  static Future<GeneratedFlashcards> generate({
    required String apiKey,
    String? rawText,
    Uint8List? bytes,
    String? mimeType,
  }) async {
    final Content content;
    if (bytes != null) {
      final mime = _resolveMime(bytes, mimeType);
      if (!_inlineMimeTypes.contains(mime)) {
        throw Exception(
            'This file type ($mime) cannot be read by the AI. Use a PDF, image, or text file.');
      }
      content = Content.multi([
        DataPart(mime, bytes), // file first, instruction after
        TextPart('Create the flashcards from the attached file.'),
      ]);
    } else if (rawText != null && rawText.trim().isNotEmpty) {
      content = Content.text(
          'Create the flashcards from this material:\n\n${rawText.trim()}');
    } else {
      throw Exception('There is no content to process.');
    }

    Object? lastError;

    for (final modelName in [primaryModel, ...fallbackModels]) {
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final model = GenerativeModel(
            model: modelName,
            apiKey: apiKey,
            systemInstruction: Content.system(_systemPrompt),
            generationConfig: GenerationConfig(
              temperature: temperature,
              maxOutputTokens: maxOutputTokens,
              responseMimeType: 'application/json',
              responseSchema: _schema,
            ),
          );

          final response =
              await model.generateContent([content]).timeout(requestTimeout);

          final text = response.text; // can throw if the prompt was blocked
          if (text == null || text.trim().isEmpty) {
            throw const FormatException('The AI returned an empty response.');
          }
          return parseFlashcards(text);
        } on FormatException catch (e) {
          lastError = e; // bad/empty output: retry same model once
          debugPrint('[Gemini] $modelName parse issue: $e');
        } on TimeoutException catch (e) {
          lastError = e;
        } catch (e) {
          lastError = e;
          final msg = e.toString().toLowerCase();
          debugPrint('[Gemini] $modelName error: $e');

          if (_isModelMissing(msg)) break; // go to next model immediately
          if (_isFatal(msg)) throw Exception(_friendlyError(e));
          // quota / overloaded / network: back off, retry, then next model
          await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
        }
      }
    }

    throw Exception(_friendlyError(lastError));
  }

  // ---------------------------------------------------------------------------
  // SAFE JSON PARSING WITH TRUNCATION REPAIR
  // ---------------------------------------------------------------------------
  @visibleForTesting
  static GeneratedFlashcards parseFlashcards(String raw) {
    var text = raw.trim();

    // Strip markdown fences if the model ignored JSON mode.
    text = text
        .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s*```\s*$'), '')
        .trim();

    // Drop any chatter before the JSON starts.
    final start = text.indexOf(RegExp(r'[\{\[]'));
    if (start == -1) {
      throw const FormatException('The AI response did not contain JSON.');
    }
    text = text.substring(start);

    dynamic decoded;
    var repaired = false;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      final fixed = _repairTruncatedJson(text);
      if (fixed == null) {
        throw const FormatException(
            'The AI response was cut off before any complete flashcard.');
      }
      decoded = jsonDecode(fixed);
      repaired = true;
    }

    String title = 'Generated Flashcards';
    List<dynamic> rawCards = const [];
    if (decoded is Map) {
      final t = decoded['title']?.toString().trim();
      if (t != null && t.isNotEmpty) title = t;
      final f = decoded['flashcards'];
      if (f is List) rawCards = f;
    } else if (decoded is List) {
      rawCards = decoded;
    }

    final cards = <Map<String, String>>[];
    for (final item in rawCards) {
      if (item is! Map) continue;
      final q = item['question']?.toString().trim() ?? '';
      final a = item['answer']?.toString().trim() ?? '';
      if (q.isEmpty || a.isEmpty) continue;
      cards.add({'question': q, 'answer': a});
    }

    if (cards.isEmpty) {
      throw const FormatException('The AI did not return any usable flashcards.');
    }
    return GeneratedFlashcards(title, cards, wasRepaired: repaired);
  }

  /// Walks the text tracking strings/escapes/brackets. If the JSON is cut off,
  /// rolls back to the last fully-closed array element and appends the missing
  /// closers. Returns null if nothing salvageable exists.
  static String? _repairTruncatedJson(String s) {
    final stack = <String>[];
    var inString = false;
    var escaped = false;
    var safePos = -1;
    var safeClosers = '';

    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (c == r'\') {
          escaped = true;
        } else if (c == '"') {
          inString = false;
        }
        continue;
      }
      if (c == '"') {
        inString = true;
      } else if (c == '{' || c == '[') {
        stack.add(c);
      } else if (c == '}' || c == ']') {
        if (stack.isNotEmpty) stack.removeLast();
        if (stack.isEmpty) return s.substring(0, i + 1); // already complete
        if (c == '}' && stack.last == '[') {
          // an array element (one flashcard) just closed cleanly
          safePos = i + 1;
          safeClosers =
              stack.reversed.map((b) => b == '[' ? ']' : '}').join();
        }
      }
    }

    if (safePos == -1) return null;
    return s.substring(0, safePos) + safeClosers;
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------
  /// Trust the file's magic bytes over a picker-supplied MIME (often null/wrong).
  static String _resolveMime(Uint8List b, String? declared) {
    if (b.length > 12) {
      if (b[0] == 0x25 && b[1] == 0x50 && b[2] == 0x44 && b[3] == 0x46) {
        return 'application/pdf'; // %PDF
      }
      if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
        return 'image/png';
      }
      if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'image/jpeg';
      if (b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 &&
          b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) {
        return 'image/webp'; // RIFF....WEBP
      }
    }
    var m = (declared ?? '').toLowerCase().trim();
    if (m == 'image/jpg') m = 'image/jpeg';
    return m;
  }

  static bool _isModelMissing(String msg) =>
      msg.contains('not found') ||
      msg.contains('404') ||
      msg.contains('is not supported for generatecontent');

  static bool _isFatal(String msg) =>
      msg.contains('api key') ||
      msg.contains('api_key') ||
      msg.contains('permission') ||
      msg.contains('403') ||
      msg.contains('blocked') ||
      msg.contains('safety') ||
      msg.contains('unsupported mime') ||
      msg.contains('invalid argument');

  static String _friendlyError(Object? e) {
    final msg = (e ?? '').toString();
    final l = msg.toLowerCase();
    if (l.contains('api key') || l.contains('api_key')) {
      return 'Your Gemini API key was rejected. Check GEMINI_API_KEY in .env.';
    }
    if (l.contains('429') || l.contains('quota') || l.contains('exhausted')) {
      return 'API rate limit reached. Please wait a few seconds and try again.';
    }
    if (l.contains('blocked') || l.contains('safety')) {
      return 'The AI declined to process this content. Try different material.';
    }
    if (l.contains('404') || l.contains('not found')) {
      return 'No Gemini model was available for this API key. Update primaryModel in gemini_flashcard_service.dart.';
    }
    if (e is TimeoutException) {
      return 'The request timed out. Try a smaller file or check your connection.';
    }
    if (e is FormatException) return e.message;
    if (l.contains('socket') || l.contains('network') || l.contains('failed host')) {
      return 'Network error. Please check your connection and try again.';
    }
    return msg.isEmpty ? 'Unable to reach Gemini AI. Please try again.' : msg;
  }
}

// -----------------------------------------------------------------------------
// DOCX -> plain text (Gemini cannot read .docx as inline data)
// -----------------------------------------------------------------------------
class DocxTextExtractor {
  static String? extract(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final doc = archive.files.firstWhere((f) => f.name == 'word/document.xml');
      var xml = utf8.decode(doc.content as List<int>, allowMalformed: true);
      xml = xml
          .replaceAll(RegExp(r'</w:p>'), '\n')
          .replaceAll(RegExp(r'<w:tab/>'), '\t')
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&apos;', "'");
      final out = xml.trim();
      return out.isEmpty ? null : out;
    } catch (_) {
      return null; // not a valid .docx (e.g. legacy binary .doc)
    }
  }
}
