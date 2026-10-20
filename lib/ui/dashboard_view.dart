import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'nocturne_theme.dart';

class DashboardView extends StatefulWidget {
  final String displayName;
  final Widget avatar;
  final VoidCallback onLibrary;
  final VoidCallback onCamera;
  final VoidCallback onImport;
  final ValueChanged<String> onGenerate;
  final bool isProcessing;
  final String processingMessage;

  const DashboardView({
    super.key,
    required this.displayName,
    required this.avatar,
    required this.onLibrary,
    required this.onCamera,
    required this.onImport,
    required this.onGenerate,
    this.isProcessing = false,
    this.processingMessage = 'Finding the key ideas in your notes…',
  });

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted) return;
      if (data?.text?.trim().isNotEmpty ?? false) {
        _notes.text = data!.text!;
        _notes.selection = TextSelection.collapsed(offset: _notes.text.length);
      } else {
        _showMessage('Copy some text first, then paste it here.');
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Couldn’t read your clipboard. Try typing your notes.');
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.displayName.trim().split(RegExp(r'\s+')).first;
    return PopScope(
      canPop: !widget.isProcessing,
      child: Scaffold(
        body: Stack(
          children: [
            NightBackdrop(
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
                      child: Row(
                        children: [
                          const Expanded(child: BrandMark()),
                          IconButton(
                            tooltip: 'Your library and account',
                            onPressed: widget.onLibrary,
                            icon: widget.avatar,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1000),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  firstName.isEmpty
                                      ? 'YOUR STUDY SPACE'
                                      : 'HELLO, ${firstName.toUpperCase()}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: NocturneTheme.eyebrow,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'What will you\nuncover today?',
                                  style: NocturneTheme.heading.copyWith(
                                    fontSize: 46,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'A page of notes. A new perspective.',
                                  style: TextStyle(
                                    color: NocturneTheme.muted,
                                    fontSize: 14,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 30),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    if (constraints.maxWidth > 700) {
                                      return Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(flex: 3, child: _editor()),
                                          const SizedBox(width: 20),
                                          Expanded(
                                            flex: 2,
                                            child: _sources(stacked: true),
                                          ),
                                        ],
                                      );
                                    }
                                    return Column(
                                      children: [
                                        _editor(),
                                        const SizedBox(height: 24),
                                        _sources(),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 28),
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.auto_awesome_outlined,
                                      size: 16,
                                      color: NocturneTheme.gold,
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Small discoveries. Lasting knowledge.',
                                        style: TextStyle(
                                          color: NocturneTheme.muted,
                                          fontSize: 12,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        color: NocturneTheme.background,
                        border: Border(
                          top: BorderSide(color: NocturneTheme.border),
                        ),
                      ),
                      child: NavigationBar(
                        selectedIndex: 0,
                        onDestinationSelected: (index) {
                          if (index == 1) widget.onLibrary();
                        },
                        height: 72,
                        backgroundColor: Colors.transparent,
                        surfaceTintColor: Colors.transparent,
                        indicatorColor: NocturneTheme.accent.withValues(
                          alpha: 0.12,
                        ),
                        destinations: const [
                          NavigationDestination(
                            icon: Icon(Icons.auto_awesome_outlined, size: 22),
                            label: 'Create',
                          ),
                          NavigationDestination(
                            icon: Icon(
                              Icons.collections_bookmark_outlined,
                              size: 22,
                            ),
                            label: 'Library',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.isProcessing) ...[
              const ModalBarrier(
                key: Key('processing-barrier'),
                dismissible: false,
                color: Color(0xDD101017),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Semantics(
                    liveRegion: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(strokeWidth: 2),
                        const SizedBox(height: 28),
                        Text(
                          'Connecting the ideas',
                          textAlign: TextAlign.center,
                          style: NocturneTheme.heading.copyWith(fontSize: 34),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.processingMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: NocturneTheme.muted,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _editor() => Container(
    decoration: BoxDecoration(
      color: NocturneTheme.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: NocturneTheme.border),
    ),
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Start with a thought',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            TextButton.icon(
              onPressed: widget.isProcessing ? null : _paste,
              icon: const Icon(Icons.content_paste_rounded, size: 16),
              label: const Text('Paste', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        TextField(
          key: const Key('notes-input'),
          controller: _notes,
          enabled: !widget.isProcessing,
          minLines: 4,
          maxLines: 8,
          keyboardType: TextInputType.multiline,
          style: const TextStyle(fontSize: 14, height: 1.7),
          decoration: const InputDecoration(
            hintText:
                'Paste your notes, a passage, or something you want to remember…',
            hintStyle: TextStyle(
              color: NocturneTheme.muted,
              fontSize: 14,
              height: 1.7,
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 14),
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
          ),
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _notes,
          builder: (context, value, _) => ElevatedButton(
            key: const Key('generate-flashcards'),
            onPressed: widget.isProcessing || value.text.trim().isEmpty
                ? null
                : () {
                    FocusScope.of(context).unfocus();
                    widget.onGenerate(value.text.trim());
                  },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(child: Text('Create flashcards')),
                  SizedBox(width: 12),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _sources({bool stacked = false}) {
    final camera = _SourceCard(
      icon: Icons.camera_alt_outlined,
      title: 'Capture a page',
      subtitle: 'From paper to possibilities',
      onTap: widget.onCamera,
    );
    final upload = _SourceCard(
      icon: Icons.upload_file_outlined,
      title: 'Import a file',
      subtitle: 'PDF, DOCX, TXT or image',
      onTap: widget.onImport,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('OR BRING YOUR NOTES', style: NocturneTheme.eyebrow),
        const SizedBox(height: 14),
        if (stacked) ...[
          camera,
          const SizedBox(height: 14),
          upload,
        ] else
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 330 ||
                  MediaQuery.textScalerOf(context).scale(14) > 20) {
                return Column(
                  children: [camera, const SizedBox(height: 12), upload],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: camera),
                  const SizedBox(width: 12),
                  Expanded(child: upload),
                ],
              );
            },
          ),
        const SizedBox(height: 12),
        const Text(
          'Files up to 10 MB',
          style: TextStyle(color: NocturneTheme.muted, fontSize: 11),
        ),
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SourceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: NocturneTheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: NocturneTheme.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: NocturneTheme.accent, size: 23),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              style: const TextStyle(
                color: NocturneTheme.muted,
                fontSize: 11,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
