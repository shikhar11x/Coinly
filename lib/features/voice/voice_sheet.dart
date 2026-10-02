import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/theme.dart';
import '../../core/ui_kit.dart';

const _englishExamples = [
  'Spent 400 on groceries yesterday',
  'Received 25000 salary today',
  'Auto 120',
  'Paid 1.5k for electricity',
];

const _hindiExamples = [
  'kal grocery pe 400 rupaye kharch kiye',
  'aaj 25000 salary mili',
  'auto ka 120 diya',
];

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

class _VoiceSheetState extends State<_VoiceSheet>
    with SingleTickerProviderStateMixin {
  final _speech = SpeechToText();
  final _text = TextEditingController();

  /// Drives the pulsing rings while listening.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );

  /// 0..1, how loud the user is (smoothed). Listened to by the rings only.
  final ValueNotifier<double> _level = ValueNotifier(0);
  double _minLevel = double.infinity;
  double _maxLevel = double.negativeInfinity;

  bool _ready = false;
  bool _listening = false;
  bool _hindi = false;
  String? _message; // hint or error shown under the mic
  bool _messageIsError = false;
  Map<String, String> _locales = {}; // "en_IN" -> the phone's real id

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    unawaited(_speech.cancel());
    _pulse.dispose();
    _level.dispose();
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
        _messageIsError = true;
      }
    });
  }

  void _setListening(bool v) {
    if (!mounted) return;
    setState(() => _listening = v);
    if (v) {
      _pulse.repeat();
    } else {
      _pulse.stop();
      _pulse.value = 0;
      _level.value = 0;
    }
  }

  void _onStatus(String status) {
    if (status == 'notListening' || status == 'done') _setListening(false);
  }

  void _onError(SpeechRecognitionError e) {
    if (!mounted) return;
    _setListening(false);
    setState(() {
      switch (e.errorMsg) {
        case 'error_no_match':
        case 'error_speech_timeout':
          // Only complain if we have nothing yet.
          if (_text.text.trim().isEmpty) {
            _message = "Didn't catch that. Tap the mic and try again.";
            _messageIsError = false;
          }
        case 'error_permission':
          _message =
              'Microphone permission is off. Enable it in Settings, or type below.';
          _messageIsError = true;
        default:
          _message =
              'Could not hear you (${e.errorMsg}). Try again or type below.';
          _messageIsError = true;
      }
    });
  }

  /// The platforms report loudness on different scales, so we learn the range
  /// as we go and turn it into 0..1.
  void _onLevel(double l) {
    _minLevel = math.min(_minLevel, l);
    _maxLevel = math.max(_maxLevel, l);
    final span = _maxLevel - _minLevel;
    final n = span < 1 ? 0.0 : ((l - _minLevel) / span).clamp(0.0, 1.0);
    _level.value = _level.value * 0.6 + n * 0.4;
  }

  String? get _localeId => _locales[_hindi ? 'hi_IN' : 'en_IN'];

  Future<void> _toggle() async {
    if (!_ready) return;
    HapticFeedback.selectionClick();

    if (_listening) {
      await _speech.stop();
      _setListening(false);
      return;
    }

    _minLevel = double.infinity;
    _maxLevel = double.negativeInfinity;
    setState(() {
      _message = (_hindi && _localeId == null)
          ? "Hindi isn't installed on this phone, so the default language is used."
          : null;
      _messageIsError = false;
    });
    _setListening(true);

    try {
      await _speech.listen(
        onResult: (r) {
          if (!mounted) return;
          setState(() {
            _text.text = r.recognizedWords;
            _text.selection = TextSelection.collapsed(offset: _text.text.length);
          });
        },
        onSoundLevelChange: _onLevel,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          localeId: _localeId,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _setListening(false);
      setState(() {
        _message = 'Could not start listening. Try again or type below.';
        _messageIsError = true;
      });
    }
  }

  Future<void> _useExample(String s) async {
    if (_listening) {
      await _speech.stop();
      _setListening(false);
    }
    if (!mounted) return;
    HapticFeedback.selectionClick();
    setState(() {
      _text.text = s;
      _text.selection = TextSelection.collapsed(offset: s.length);
    });
  }

  Future<void> _submit() async {
    await _speech.stop();
    if (!mounted) return;
    Navigator.pop(context, _text.text.trim());
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final canSubmit = _text.text.trim().length >= 3;
    final examples = _hindi ? _hindiExamples : _englishExamples;

    final status = _listening
        ? 'Listening… speak now'
        : (_message ??
            (_ready ? 'Tap the mic and speak' : 'Getting the microphone ready…'));

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
          Text(
            'Voice entry',
            textAlign: TextAlign.center,
            style: context.tt.titleLarge,
          ),
          const SizedBox(height: 2),
          Text(
            'Say one transaction at a time',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: context.muted),
          ),
          const SizedBox(height: 14),

          // ---------- Language ----------
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('English'),
                selected: !_hindi,
                onSelected:
                    _listening ? null : (_) => setState(() => _hindi = false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('हिन्दी'),
                selected: _hindi,
                onSelected:
                    _listening ? null : (_) => setState(() => _hindi = true),
              ),
            ],
          ),

          // ---------- Mic with pulsing rings ----------
          const SizedBox(height: 6),
          Center(
            child: SizedBox(
              width: 180,
              height: 180,
              child: AnimatedBuilder(
                animation: Listenable.merge([_pulse, _level]),
                builder: (context, child) {
                  Widget ring(double phase) {
                    final p = (_pulse.value + phase) % 1.0;
                    final size = 84 + (34 + 48 * _level.value) * p;
                    return Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.red.withValues(alpha: 0.22 * (1 - p)),
                      ),
                    );
                  }

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_listening) ring(0),
                      if (_listening) ring(0.5),
                      child!,
                    ],
                  );
                },
                child: GestureDetector(
                  onTap: _ready ? _toggle : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: !_ready
                          ? context.cs.outline
                          : (_listening ? AppColors.red : AppColors.green),
                      boxShadow: _ready
                          ? [
                              BoxShadow(
                                color: (_listening
                                        ? AppColors.red
                                        : AppColors.green)
                                    .withValues(alpha: 0.40),
                                blurRadius: 22,
                                offset: const Offset(0, 8),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      _listening ? Icons.stop_rounded : Icons.mic_rounded,
                      size: 38,
                      color: _listening ? Colors.white : AppColors.dark,
                    ),
                  ),
                ),
              ),
            ),
          ),

          Text(
            status,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              fontWeight: _listening ? FontWeight.w700 : FontWeight.w500,
              color: _messageIsError && !_listening
                  ? AppColors.red
                  : context.muted,
            ),
          ),
          const SizedBox(height: 18),

          // ---------- What was heard (editable) ----------
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
              hintText: 'e.g. ${examples.first}',
              counterText: '',
            ),
          ),

          // ---------- Examples ----------
          const SizedBox(height: 14),
          Text(
            'TRY SAYING',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: context.muted,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in examples)
                ActionChip(
                  label: Text(e),
                  onPressed: () => _useExample(e),
                ),
            ],
          ),

          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Fill the form',
            icon: Icons.auto_awesome_rounded,
            onPressed: canSubmit ? _submit : null,
          ),
        ],
      ),
    );
  }
}