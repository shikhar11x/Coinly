import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../core/theme.dart';

/// Returns what the user said/typed, or null if they closed the sheet.
Future<String?> showVoiceSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _VoiceSheet(),
  );
}

class _VoiceSheet extends StatefulWidget {
  const _VoiceSheet();

  @override
  State<_VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<_VoiceSheet> {
  final _speech = SpeechToText();
  final _text = TextEditingController();

  bool _ready = false;
  bool _listening = false;
  bool _hindi = false;
  String? _message; // hint or error shown under the mic
  Map<String, String> _locales = {}; // "en_IN" -> the phone's real id

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    unawaited(_speech.cancel());
    _text.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    var ok = false;
    try {
      ok = await _speech.initialize(onStatus: _onStatus, onError: _onError);
    } catch (_) {}

    var locales = <String, String>{};
    if (ok) {
      try {
        final list = await _speech.locales();
        locales = {
          for (final l in list) l.localeId.replaceAll('-', '_'): l.localeId,
        };
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _ready = ok;
      _locales = locales;
      if (!ok) {
        _message = 'Speech recognition is not available here. '
            'Check the microphone permission, or type below.';
      }
    });
  }

  void _onStatus(String status) {
    if (!mounted) return;
    if (status == 'notListening' || status == 'done') {
      setState(() => _listening = false);
    }
  }

  void _onError(SpeechRecognitionError e) {
    if (!mounted) return;
    setState(() {
      _listening = false;
      switch (e.errorMsg) {
        case 'error_no_match':
        case 'error_speech_timeout':
          // Only complain if we have nothing yet.
          if (_text.text.trim().isEmpty) {
            _message = "Didn't catch that. Tap the mic and try again.";
          }
        case 'error_permission':
          _message =
              'Microphone permission is off. Enable it in Settings, or type below.';
        default:
          _message = 'Could not hear you (${e.errorMsg}). Try again or type below.';
      }
    });
  }

  String? get _localeId => _locales[_hindi ? 'hi_IN' : 'en_IN'];

  Future<void> _toggle() async {
    if (!_ready) return;

    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    setState(() {
      _listening = true;
      _message = (_hindi && _localeId == null)
          ? "Hindi isn't installed on this phone, so the default language is used."
          : null;
    });

    try {
      await _speech.listen(
        onResult: (r) {
          if (!mounted) return;
          setState(() {
            _text.text = r.recognizedWords;
            _text.selection = TextSelection.collapsed(offset: _text.text.length);
          });
        },
        localeId: _localeId,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _listening = false;
        _message = 'Could not start listening. Try again or type below.';
      });
    }
  }

  Future<void> _submit() async {
    await _speech.stop();
    if (!mounted) return;
    Navigator.pop(context, _text.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _text.text.trim().length >= 3;
    final example = _hindi
        ? 'kal grocery pe 400 rupaye kharch kiye'
        : 'Spent 400 on groceries yesterday';

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Voice entry',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'One transaction at a time.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // Language
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('English'),
                selected: !_hindi,
                onSelected: _listening
                    ? null
                    : (_) => setState(() => _hindi = false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('हिन्दी'),
                selected: _hindi,
                onSelected: _listening
                    ? null
                    : (_) => setState(() => _hindi = true),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Mic button
          Center(
            child: GestureDetector(
              onTap: _ready ? _toggle : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _listening ? 88 : 76,
                height: _listening ? 88 : 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: !_ready
                      ? Colors.black12
                      : _listening
                          ? AppColors.red
                          : AppColors.green,
                  boxShadow: _listening
                      ? [
                          BoxShadow(
                            color: AppColors.red.withValues(alpha: 0.35),
                            blurRadius: 24,
                            spreadRadius: 6,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  _listening ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _listening
                ? 'Listening… speak now'
                : (_message ?? 'Tap the mic and speak'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // What was heard (editable)
          TextField(
            controller: _text,
            minLines: 2,
            maxLines: 4,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            onTap: () {
              if (_listening) _toggle(); // stop so typing isn't overwritten
            },
            decoration: InputDecoration(
              labelText: 'What you said (you can edit)',
              hintText: 'e.g. $example',
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),

          FilledButton(
            onPressed: canSubmit ? _submit : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.green,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Fill the form'),
          ),
        ],
      ),
    );
  }
}