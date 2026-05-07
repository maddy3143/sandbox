import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

class AudioService {
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();

  bool _sttAvailable = false;
  bool _isSpeaking = false;
  bool _isListening = false;

  AudioService() {
    _initTts();
    _initStt();
  }

  void _initTts() {
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.9);
    _tts.setVolume(1.0);
    _tts.setPitch(1.0);
    _tts.setCompletionHandler(() => _isSpeaking = false);
    _tts.setStartHandler(() => _isSpeaking = true);
  }

  Future<void> _initStt() async {
    _sttAvailable = await _stt.initialize(
      onStatus: (status) {
        if (status == 'done') _isListening = false;
      },
      onError: (error) {
        _isListening = false;
      },
    );
  }

  Future<void> speak(String text) async {
    if (_isSpeaking) await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  Future<String?> listen({
    int listenDurationSeconds = 10,
    Function(String partialResult)? onPartialResult,
  }) async {
    if (!_sttAvailable) return null;

    String? finalResult;
    _isListening = true;

    await _stt.listen(
      onResult: (result) {
        if (result.finalResult) {
          finalResult = result.recognizedWords;
          _isListening = false;
        } else if (onPartialResult != null) {
          onPartialResult(result.recognizedWords);
        }
      },
      listenFor: Duration(seconds: listenDurationSeconds),
      localeId: 'en_US',
      cancelOnError: true,
      partialResults: true,
    );

    await Future.delayed(Duration(seconds: listenDurationSeconds));
    return finalResult;
  }

  Future<void> stopListening() async {
    await _stt.stop();
    _isListening = false;
  }

  bool get isSpeaking => _isSpeaking;
  bool get isListening => _isListening;
  bool get sttAvailable => _sttAvailable;

  void dispose() {
    _tts.stop();
    _stt.stop();
  }
}
