import 'package:flutter_tts/flutter_tts.dart';
import 'background_audio_service.dart';

class VoiceService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;

  Future<void> _init() async {
    if (_isInitialized) return;

    // 1. Set Language
    await _tts.setLanguage("en-US");

    // 2. WARMTH SETTINGS
    // 0.45 - 0.50 is the "sweet spot" for a natural human talking pace.
    await _tts.setSpeechRate(0.53); 
    // 1.0 or 1.1 is warmer. 1.2 often sounds too "chipmunk-like" and robotic.
    await _tts.setPitch(1.0); 
    await _tts.setVolume(1.0);

    // 3. TARGET ENHANCED/WARM VOICES
    try {
      List<dynamic> voices = await _tts.getVoices;
      
      // We look for "Enhanced" or "Premium" which are high-quality natural recordings
      var bestVoice = voices.firstWhere(
        (v) => (v["name"].toString().contains("Enhanced") || v["name"].toString().contains("Premium")) 
               && v["locale"].toString().contains("en-US"),
        orElse: () => voices.firstWhere(
          (v) => v["name"].toString().contains("Samantha") || v["name"].toString().contains("Ava"),
          orElse: () => voices.firstWhere((v) => v["locale"].toString().contains("en-US"))
        )
      );

      if (bestVoice != null) {
        await _tts.setVoice({"name": bestVoice["name"], "locale": bestVoice["locale"]});
      }
    } catch (e) {
      print("Error finding warm voice: $e");
    }

    _tts.setStartHandler(() => BackgroundAudioService().setVolume(0.05));
    _tts.setCompletionHandler(() => BackgroundAudioService().setVolume(0.2));

    _isInitialized = true;
  }

  Future<void> speak(String text, {bool withDelay = false}) async {
    await _init();

    // Clean emojis
    String cleanText = text.replaceAll(RegExp(r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]', unicode: true), '');

    if (withDelay) {
      await Future.delayed(const Duration(seconds: 3));
    }
    
    await _tts.speak(cleanText);
  }

  void stop() => _tts.stop();
}