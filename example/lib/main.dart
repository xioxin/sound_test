import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:lab_sound/lab_sound.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:lab_sound_example/player.dart';
import 'package:path_provider/path_provider.dart';

import 'music-time.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  AudioContext audioContext;
  AudioBus musicBus;
  AudioBus synthesizerHighBus;
  AudioBus synthesizerLowBus;
  AudioPlayerNode musicNode;

  GainNode gainNode;

  String musicPath;
  String synthesizerHighPath;
  String synthesizerLowPath;

  double _playbackRate = 1.0;

  double _tempo = 1.0;
  double _pitch = 1.0;

  @override
  void initState() {
    super.initState();
    initPath();
    audioContext = AudioContext(channels: 2, initSampleRate: 48000.0);
  }

  initPath() async {
    this.musicPath = await loadAsset('music.mp3');
    this.synthesizerHighPath = await loadAsset('synthesizer-high.wav');
    this.synthesizerLowPath = await loadAsset('synthesizer-low.wav');
  }

  Future<String> loadAsset(String path) async {
    final tempDir = await getTemporaryDirectory();
    final file = File(tempDir.path + '/' + path);
    await file.writeAsBytes(
        (await rootBundle.load('assets/' + path)).buffer.asUint8List());
    return file.path;
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
  }

  void play1() async {
    if (musicNode != null) {
      musicNode.start(when: 0);
      return;
    }
    print(48000.0);
    final ctx = audioContext;
    musicBus ??= ctx.decodeAudioFile(musicPath);
    synthesizerHighBus ??= ctx.decodeAudioFile(synthesizerHighPath);
    synthesizerLowBus ??= ctx.decodeAudioFile(synthesizerLowPath);
    musicNode = ctx.createSoundTouch(musicBus);

//    musicNode.tempo = 2.0;
    
    print("musicBus: length:${musicBus.length}, numberOfChannels: ${musicBus.numberOfChannels}, sampleRate:${musicBus.sampleRate}, duration: ${musicBus.duration}");
    
    final startTime = ctx.currentTime + 0.5;
//    musicNode.playbackRate.setValueAtTime(3, startTime + 2.0);
    gainNode = ctx.createGainNode();
    gainNode.connect(ctx.destination);
    musicNode.connect(gainNode);
    musicNode.start(when: startTime);

    gainNode.gain.setValue(0.1);
    gainNode.gain.linearRampToValueAtTime(1.0, 5.0);


//    print(' musicNode.playbackRate: ${musicNode.playbackRate.value}');

//    musicNode.playbackRate.setValue(1.5);
//    musicNode.detune.setValue(0.5);

//    musicNode.gain.setValue(0.1);
//    musicNode.gain.linearRampToValueAtTime(1.0, startTime + 5);




//    musicNode.playbackRate.setValueAtTime(0.5, startTime + 5.0);
//    musicNode.gain.setValueAtTime(0.5, startTime + 10.0);

//    musicNode.playbackRate.setValue(0.5);

//
//    final time = musicTime;
//    int index = 0;
//    time.forEach((v) {
//      if (index++ % 4 == 0) {
//        final highNode = ctx.createBufferSource(synthesizerHighBus);
//        highNode.connect(gainNode);
//        highNode.start(when: startTime + (v / 1000));
//      } else {
//        final lowNode = ctx.createBufferSource(synthesizerLowBus);
//        lowNode.connect(gainNode);
//        lowNode.start(when: startTime + (v / 1000));
//      }
//    });
//
//    List<double> times = [];
//    double lastTime = 0.0;
//    final timer = Timer.periodic(Duration(milliseconds: 1000), (timer) {
//      if (lastTime > 0) {
//        times.add(ctx.currentTime - lastTime);
//        print(
//            "currentTime:${ctx.currentTime} - diff:${ctx.currentTime - lastTime} - sampleRate:${ctx.sampleRate.round()} - currentSampleFrame: ${ctx.currentSampleFrame} - ${times.reduce((a, b) => a + b) / times.length}");
//      }
//      lastTime = ctx.currentTime;
//    });

//    musicNode.ended.listen((event) {
//      print("结束");
////      timer.cancel();
//    });
  }

  void stop() async {
    musicNode.stop();
  }


  void testPlay2() async {
    print('testPlay2');
    final musicPath = await loadAsset('mono-music-clip.wav');
    final ctx = AudioContext();
    final musicBus = ctx.decodeAudioFile(musicPath);
    final musicNode = ctx.createBufferSource(musicBus);
    musicNode.connect(ctx.destination);
    final startTime = ctx.currentTime + 0.5;
    musicNode.start(when: startTime);
  }

  void offlineTest() async {
    print(48000.0);
    final tempDir = await getTemporaryDirectory();
    final saveFile = File(tempDir.path + '/' + 'temp.wav');
    print(saveFile.path);
    print(saveFile.existsSync());



    final ctx = AudioContext(offline: true, channels: 2, initSampleRate: 48000.0, timeMills: 60.0 * 1000);
//    print(ctx.sampleRate);
    final recorder = ctx.createRecorderNode();
    final musicBus = ctx.decodeAudioFile(musicPath);
    final synthesizerHighBus = ctx.decodeAudioFile(synthesizerHighPath);
    final synthesizerLowBus = ctx.decodeAudioFile(synthesizerLowPath);
    final musicNode = ctx.createBufferSource(musicBus);
    final startTime = ctx.currentTime + 0.5;
    final gainNode = ctx.createGainNode();
    gainNode.connect(recorder);
    musicNode.connect(gainNode);
    musicNode.start(when: startTime);

    gainNode.gain.setValue(0.1);
    gainNode.gain.linearRampToValueAtTime(1.0, 5.0);


//    print(' musicNode.playbackRate: ${musicNode.playbackRate.value}');

//    musicNode.playbackRate.setValue(1.5);
//    musicNode.detune.setValue(0.5);

//    musicNode.gain.setValue(0.1);
//    musicNode.gain.linearRampToValueAtTime(1.0, startTime + 5);

//    musicNode.playbackRate.setValueAtTime(0.5, startTime + 5.0);
//    musicNode.gain.setValueAtTime(0.5, startTime + 10.0);

//    musicNode.playbackRate.setValue(0.5);

    final time = musicTime;
    int index = 0;
    time.forEach((v) {
      if (index++ % 4 == 0) {
        final highNode = ctx.createBufferSource(synthesizerHighBus);
        highNode.connect(gainNode);
        highNode.start(when: startTime + (v / 1000));
      } else {
        final lowNode = ctx.createBufferSource(synthesizerLowBus);
        lowNode.connect(gainNode);
        lowNode.start(when: startTime + (v / 1000));
      }
    });

    ctx.startOfflineRendering(saveFile.path, recorder);
    print("saveFile: ${saveFile.existsSync()}");

//    List<double> times = [];
//    double lastTime = 0.0;
//    final timer = Timer.periodic(Duration(milliseconds: 1000), (timer) {
//      if (lastTime > 0) {
//        times.add(ctx.currentTime - lastTime);
//        print(
//            "currentTime:${ctx.currentTime} - diff:${ctx.currentTime - lastTime} - sampleRate:${ctx.sampleRate.round()} - currentSampleFrame: ${ctx.currentSampleFrame} - ${times.reduce((a, b) => a + b) / times.length}");
//      }
//      lastTime = ctx.currentTime;
//    });



  }

  void offlineTest2() async {
    print(48000.0);
    final tempDir = await getTemporaryDirectory();
    final saveFile = File(tempDir.path + '/' + 'temp.wav');
    print(saveFile.path);
    print("file exists1: ${saveFile.existsSync()}");
    if(saveFile.existsSync()){
      saveFile.deleteSync();
    }
    final ctx = AudioContext(offline: true, channels: 2, initSampleRate: 48000.0, timeMills: 30.0*1000.0);
    final recorder = ctx.createRecorderNode();
    final musicBus = ctx.decodeAudioFile(musicPath);
    final musicNode = ctx.createBufferSource(musicBus);
    musicNode.connect(recorder);
    musicNode.start(when: 0);
    print("开始渲染");
    ctx.startOfflineRendering(saveFile.path, recorder);
    print("file exists2: ${saveFile.existsSync()}");

    // 播放。。。
    final ctx2 = AudioContext();
    final musicBus2 = ctx2.decodeAudioFile(saveFile.path);
    final musicNode2 = ctx2.createBufferSource(musicBus2);
    musicNode2.connect(ctx2.destination);
    musicNode2.start(when: 0);
  }

  void memoryTest() async {
    final ctx = AudioContext(channels: 2, initSampleRate: 48000.0);
    for(int i = 0; i < 100; i++) {
      print('noDis: $i');
      ctx.decodeAudioFile(musicPath);
    }
  }

  void memoryTest2() async {
    final ctx = AudioContext(channels: 2, initSampleRate: 48000.0);
    for(int i = 0; i < 100; i++) {
      print('dispose: $i');
      final bus = ctx.decodeAudioFile(musicPath);
      bus.dispose();
    }
  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Builder(
          builder: (context) {
            return Center(
                child: Column(
              children: [
                if(musicNode != null)StreamBuilder<Duration>(
                  stream: musicNode.onPosition,
                  builder: (context, snapshot) {
                    return LinearProgressIndicator(value: snapshot.data.inMilliseconds / musicNode.duration.inMilliseconds);
                  }
                ),
                Text('tempo: ${_tempo.toStringAsFixed(2)}' ),
                Slider(
                    value: _tempo,
                    min: 0.3,
                    max: 2.0,
                    onChanged: (value) {
                      setState(() {
                        musicNode.tempo = value;
                        _tempo = value;
                      });
                    }),
                Text('pitch: ${_pitch.toStringAsFixed(2)}'),
                Slider(
                    value: _pitch,
                    min: 0.3,
                    max: 2.0,
                    onChanged: (value) {
                      setState(() {
                        musicNode.pitch = value;
                        _pitch = value;
                      });
                    }),
                RaisedButton(
                  child: Text("Play1"),
                  onPressed: () async {
                    play1();
                  },
                ),
                RaisedButton(
                  child: Text("stop"),
                  onPressed: () async {
                    stop();
                  },
                ),
                RaisedButton(
                  child: Text("delNode"),
                  onPressed: () async {
                    musicNode.dispose();
                  },
                ),
                RaisedButton(
                  child: Text("Play2"),
                  onPressed: () async {
                    testPlay2();
                  },
                ),
                RaisedButton(
                  child: Text("offlineTest"),
                  onPressed: () async {
                    offlineTest();
                  },
                ),
                RaisedButton(
                  child: Text("offlineTest2"),
                  onPressed: () async {
                    offlineTest2();
                  },
                ),
                RaisedButton(
                  child: Text("memoryTest"),
                  onPressed: () async {
                    memoryTest();
                  },
                ),
                RaisedButton(
                  child: Text("memoryTest2"),
                  onPressed: () async {
                    memoryTest2();
                  },
                ),


                RaisedButton(
                  child: Text("测试播放器"),
                  onPressed: () async {
                    Navigator.push(
                      context,
                      new MaterialPageRoute(builder: (context) => Player()),
                    );
                  },
                ),

              ],
            ));
          }
        ),
      ),
    );
  }
}
