//import 'dart:io';
//
//import 'package:audio_service/audio_service.dart';
//import 'package:flutter/material.dart';
//import 'dart:async';
//
//import 'package:flutter/services.dart';
//import 'package:lab_sound/lab_sound.dart';
//import 'package:flutter/services.dart' show rootBundle;
//import 'package:path_provider/path_provider.dart';
//
//void main() {
//  runApp(MyApp());
//}
//
//class MyApp extends StatefulWidget {
//  @override
//  _MyAppState createState() => _MyAppState();
//}
//
//class _MyAppState extends State<MyApp> {
//
//
//  AudioContext audioContext;
//  AudioBus musicBus;
//  AudioBus synthesizerHighBus;
//  AudioBus synthesizerLowBus;
//  AudioSampleNode musicNode;
//
//  @override
//  void initState() {
//    super.initState();
////    initPlayer();
//  }
//
//  Future<String> loadAsset(String path) async {
//    final tempDir = await getTemporaryDirectory();
//    final file = File(tempDir.path + '/' + path);
//    await file.writeAsBytes((await rootBundle.load('assets/' + path)).buffer.asUint8List());
//    return file.path;
//  }
//
//
//
//  @override
//  void dispose() {
//    // TODO: implement dispose
//    super.dispose();
//  }
//
//
//  void initPlayer() async {
//    final musicPath = await loadAsset('music.mp3');
//    final synthesizerHighPath = await loadAsset('synthesizer-high.wav');
//    final synthesizerLowPath = await loadAsset('synthesizer-low.wav');
//    print('初始化中');
//    final ok = await AudioService.start(
//      backgroundTaskEntrypoint: _audioPlayerTaskEntrypoint,
//      androidNotificationChannelName: 'Audio Service Demo',
//      androidNotificationColor: 0xFF2196f3,
//      androidNotificationIcon: 'mipmap/ic_launcher',
//      androidEnableQueue: true,
//      params: {
//        'musicPath': musicPath,
//        'synthesizerHighPath': synthesizerHighPath,
//        'synthesizerLowPath': synthesizerLowPath,
//      },
//    );
//    print('初始化完毕: ${ok}');
//  }
//
//  void play() async {
//    await AudioService.play();
////    AudioService.customAction(name)
////    AudioService.setSpeed(speed);
//  }
//
//  void stop() async {
//    await AudioService.pause();
//  }
//
//  void testPlay2() async {
//    print('testPlay2');
//    final musicPath = await loadAsset('mono-music-clip.wav');
//    final ctx = AudioContext();
//    final musicBus = ctx.decodeAudioFile(musicPath);
//    final musicNode = ctx.createBufferSource(musicBus);
//    musicNode.connect(ctx.destination);
//    final startTime = ctx.currentTime + 0.5;
//    musicNode.start(when: startTime);
//  }
//
//  @override
//  Widget build(BuildContext context) {
//    return AudioServiceWidget(
//      child: MaterialApp(
//        home: Scaffold(
//          appBar: AppBar(
//            title: const Text('Plugin example app'),
//          ),
//          body: Center(
//              child: Column(
//                children: [
//                  RaisedButton(child: Text("init"), onPressed: () async {
//                    initPlayer();
//                  },),
//                  RaisedButton(child: Text("Play"), onPressed: () async {
//                    this.play();
//                  },),
//                  RaisedButton(child: Text("Stop"), onPressed: () async {
//                    this.stop();
//                  },),
//                  RaisedButton(child: Text("Test"), onPressed: () async {
//                    this.testPlay2();
//                  },),
//                ],
//              )
//          ),
//        ),
//      ),
//    );
//  }
//}
//
//
//
//
//
//
//void _audioPlayerTaskEntrypoint() async {
//  AudioServiceBackground.run(() => AudioPlayerTask());
//}
//class AudioPlayerTask extends BackgroundAudioTask {
////
//  AudioContext audioContext;
//  AudioBus musicBus;
//  AudioBus synthesizerHighBus;
//  AudioBus synthesizerLowBus;
//  AudioSampleNode musicNode;
//
//  // 初始化音频任务
//  onStart(Map<String, dynamic> params) {
//    final musicPath = params['musicPath'];
//    final synthesizerHighPath = params['synthesizerHighPath'];
//    final synthesizerLowPath = params['synthesizerLowPath'];
//    print('onstart, $params');
//
//
//    audioContext = AudioContext(channels: 2, sampleRate: 48000.0);
//    musicBus = audioContext.decodeAudioFile(musicPath);
//    synthesizerHighBus = audioContext.decodeAudioFile(synthesizerHighPath);
//    synthesizerLowBus = audioContext.decodeAudioFile(synthesizerLowPath);
//    musicNode = audioContext.createBufferSource(musicBus);
//    musicNode.connect(audioContext.destination);
//
//  }
//  // 处理停止音频并完成任务的请求
//  onStop() async {
//    super.onStop();
//  }
//  // 处理播放音频的请求
//  onPlay() {
//    musicNode.start();
//    super.onPlay();
//  }
//  // 处理暂停音频的请求
//  onPause() {
//    musicNode.stop();
//    super.onPause();
//  }
////  // 按一下耳机按钮（播放/暂停，跳过下一步/上一步）
////  onClick(MediaButton button) {}
////  // 处理跳到下一个队列项目的请求
////  onSkipToNext() {}
////  // 处理跳到上一个队列项目的请求
////  onSkipToPrevious() {}
////
////  // 处理音频跳转到
////  onSeekTo(Duration position) {}
////
////  // 电话或其他原因打断
////  onAudioFocusLost(AudioInterruption interruption) {}
////
////  // 中断结束
////  onAudioFocusGained(AudioInterruption interruption) {}
//}
//
//
//void _textToSpeechTaskEntrypoint() async {
//  AudioServiceBackground.run(() => TextPlayerTask());
//}
//
//class TextPlayerTask extends BackgroundAudioTask {
//  bool _finished = false;
//  Sleeper _sleeper = Sleeper();
//  Completer _completer = Completer();
//
//  bool get _playing => AudioServiceBackground.state.playing;
//
//  @override
//  Future<void> onStart(Map<String, dynamic> params) async {
//    await _playPause();
//    for (var i = 1; i <= 10 && !_finished; i++) {
//      AudioServiceBackground.setMediaItem(mediaItem(i));
//      AudioServiceBackground.androidForceEnableMediaButtons();
////      _tts.speak('$i');
//      // Wait for the speech.
//      try {
//        await _sleeper.sleep(Duration(seconds: 1));
//      } catch (e) {
//        // Speech was interrupted
////        _tts.stop();
//      }
//      // If we were just paused
//      if (!_finished && !_playing) {
//        try {
//          // Wait to be unpaused
//          await _sleeper.sleep();
//        } catch (e) {
//          // unpaused
//        }
//      }
//    }
//    await AudioServiceBackground.setState(
//      controls: [],
//      processingState: AudioProcessingState.stopped,
//      playing: false,
//    );
//    if (!_finished) {
//      onStop();
//    }
//    _completer.complete();
//  }
//
//  @override
//  Future<void> onPlay() => _playPause();
//
//  @override
//  Future<void> onPause() => _playPause();
//
//  @override
//  Future<void> onStop() async {
//    // Signal the speech to stop
//    _finished = true;
//    _sleeper.interrupt();
//    // Wait for the speech to stop
//    await _completer.future;
//    // Shut down this task
//    await super.onStop();
//  }
//
//  MediaItem mediaItem(int number) => MediaItem(
//      id: 'tts_$number',
//      album: 'Numbers',
//      title: 'Number $number',
//      artist: 'Sample Artist');
//
//  Future<void> _playPause() async {
//    if (_playing) {
////      _tts.stop();
//      await AudioServiceBackground.setState(
//        controls: [MediaControl.play, MediaControl.stop],
//        processingState: AudioProcessingState.ready,
//        playing: false,
//      );
//    } else {
//      await AudioServiceBackground.setState(
//        controls: [MediaControl.pause, MediaControl.stop],
//        processingState: AudioProcessingState.ready,
//        playing: true,
//      );
//    }
//    _sleeper.interrupt();
//  }
//}
//
//class Sleeper {
//  Completer _blockingCompleter;
//
//  /// Sleep for a duration. If sleep is interrupted, a
//  /// [SleeperInterruptedException] will be thrown.
//  Future<void> sleep([Duration duration]) async {
//    _blockingCompleter = Completer();
//    if (duration != null) {
//      await Future.any([Future.delayed(duration), _blockingCompleter.future]);
//    } else {
//      await _blockingCompleter.future;
//    }
//    final interrupted = _blockingCompleter.isCompleted;
//    _blockingCompleter = null;
//    if (interrupted) {
//      throw SleeperInterruptedException();
//    }
//  }
//
//  /// Interrupt any sleep that's underway.
//  void interrupt() {
//    if (_blockingCompleter?.isCompleted == false) {
//      _blockingCompleter.complete();
//    }
//  }
//}
//
//class SleeperInterruptedException {}