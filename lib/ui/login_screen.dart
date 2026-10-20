import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'nocturne_theme.dart';

class LoginScreen extends StatefulWidget {
  final Future<void> Function() onSignIn;
  final String? connectionError;
  const LoginScreen({super.key, required this.onSignIn, this.connectionError});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isSigningIn = false;
  String? _error;

  Future<void> _signIn() async {
    if (_isSigningIn) return;
    setState(() {
      _isSigningIn = true;
      _error = null;
    });
    try {
      await widget.onSignIn();
    } on FirebaseAuthException catch (error) {
      if (mounted &&
          error.code != 'popup-closed-by-user' &&
          error.code != 'cancelled-popup-request') {
        setState(
          () => _error = switch (error.code) {
            'network-request-failed' =>
              'You seem to be offline. Check your connection and try again.',
            'too-many-requests' =>
              'Too many attempts. Please wait a moment before trying again.',
            'account-exists-with-different-credential' =>
              'This email uses another sign-in method. Try your original account.',
            'user-disabled' =>
              'This account is unavailable. Please use another Google account.',
            _ => 'We couldn’t sign you in. Please try again in a moment.',
          },
        );
      }
    } on PlatformException catch (error) {
      if (mounted && error.code != 'sign_in_canceled') {
        setState(
          () => _error = error.code == 'network_error'
              ? 'You seem to be offline. Check your connection and try again.'
              : 'Google sign-in is unavailable right now. Please try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'We couldn’t connect to sign-in. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NightBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 850;
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: wide ? 56 : 26,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 48).clamp(
                      0,
                      double.infinity,
                    ),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1080),
                      child: Column(
                        children: [
                          const Row(
                            children: [
                              BrandMark(),
                              Spacer(),
                              Icon(
                                Icons.dark_mode_outlined,
                                size: 18,
                                color: NocturneTheme.muted,
                              ),
                            ],
                          ),
                          SizedBox(height: wide ? 64 : 22),
                          if (wide)
                            Row(
                              children: [
                                const Expanded(child: _WelcomeStory()),
                                const SizedBox(width: 80),
                                Expanded(child: _loginCard()),
                              ],
                            )
                          else ...[
                            const _WelcomeStory(),
                            const SizedBox(height: 30),
                            _loginCard(),
                          ],
                          const SizedBox(height: 30),
                          const Text(
                            'A quiet place for curious minds.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: NocturneTheme.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _loginCard() {
    final error = _error ?? widget.connectionError;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: NocturneTheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NocturneTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Log in to Just Paste',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          const Text(
            'Your notes, your flashcards, your space.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: NocturneTheme.muted,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            key: const Key('google-sign-in'),
            onPressed: _isSigningIn ? null : _signIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: NocturneTheme.text,
              foregroundColor: NocturneTheme.background,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            child: _isSigningIn
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Flexible(child: Text('Signing in…')),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'G',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 12),
                      Flexible(child: Text('Continue with Google')),
                    ],
                  ),
          ),
          if (error != null) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: NocturneTheme.error,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          const Text(
            'New here? Signing in creates your account.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: NocturneTheme.muted,
              fontSize: 11,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeStory extends StatelessWidget {
  const _WelcomeStory();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const OrbitArtwork(),
      const SizedBox(height: 10),
      const Text(
        'A LITTLE CURIOSITY GOES A LONG WAY',
        textAlign: TextAlign.center,
        style: NocturneTheme.eyebrow,
      ),
      const SizedBox(height: 16),
      Text(
        'Make space\nfor discovery.',
        textAlign: TextAlign.center,
        style: NocturneTheme.heading.copyWith(fontSize: 52),
      ),
      const SizedBox(height: 16),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330),
        child: const Text(
          'Turn scattered notes into flashcards.\nFind clarity, one idea at a time.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.7,
            color: NocturneTheme.muted,
          ),
        ),
      ),
    ],
  );
}
