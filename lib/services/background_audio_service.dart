import 'package:audioplayers/audioplayers.dart';

class BackgroundAudioService {
  static final BackgroundAudioService _instance = BackgroundAudioService._internal();
  factory BackgroundAudioService() => _instance;
  BackgroundAudioService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  Future<void> start() async {
    if (_isPlaying) return;
    
    try {
      print("🎵 Background music START called"); 
      // Set to loop so music doesn't stop after 3 minutes
      await _player.setReleaseMode(ReleaseMode.loop);
      
      await _player.setVolume(0.2);
      await _player.play(AssetSource('audio/cozy_lofi.mp3'));
      
      _isPlaying = true;
    } catch (e) {
      print("❌ Error starting audio: $e");
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
      _isPlaying = false;
      print("🛑 Background music STOPPED");
    } catch (e) {
      print("❌ Error stopping audio: $e");
    }
  }

  Future<void> setVolume(double volume) async {
    // Volume should be between 0.0 and 1.0
    await _player.setVolume(volume);
  }
}