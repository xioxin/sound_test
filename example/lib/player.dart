import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lab_sound/lab_player.dart';
import 'package:lab_sound/lab_sound.dart';
import 'package:lab_sound_example/music-time.dart';
import 'package:path_provider/path_provider.dart';



class BeatSequence {
  double time;
  bool skip;
  BeatSequence({this.time, this.skip = false});
  @override
  String toString() {
    return "BS<$time, $skip>";
  }
}

class BeatPosPack {
  final double beat;
  final double startTime;
  BeatPosPack(this.beat, this.startTime);
  @override
  String toString() {
    return "BeatPosPack <beat: $beat, start: $startTime>";
  }
}


class Player extends StatefulWidget {
  Player({Key key}) : super(key: key);

  @override
  PlayerState createState() => PlayerState();
}

class PlayerState extends State<Player> {
  AudioContext get audioContext => player.audioContext ;
  final LabPlayer player = LabPlayer(audioContext: AudioContext(channels: 2, initSampleRate: 48000.0));

  double playerPosChange;
  double speed = 1;

  AudioBus synthesizerHigh;
  AudioBus synthesizerLow;

  List<BeatSequence> beatSequence = [];

  double lastTime = -1;

  Future<String> loadAsset(String path) async {
    final tempDir = await getTemporaryDirectory();
    final file = File(tempDir.path + '/' + path);
    await file.writeAsBytes(
        (await rootBundle.load('assets/' + path)).buffer.asUint8List());
    return file.path;
  }


  @override
  void initState() {
    super.initState();
    player.onPosition.listen((event) {
      beatPlayer(player.position.inMilliseconds / 1000 , player.audioContext.currentTime);
    });
    beatSequence = musicTime.map((e) => BeatSequence(time: e / 1000)).toList();
    print(beatSequence);
    initPath();
  }

  beatPlayer(double time, double deviceTime) {
    final shift = 250/1000;
    final pos = getBeatPos(time + shift); // 计提前250ms计算 提前预判播放时机
    if(pos == null) return;
    if((time + shift) >= pos.startTime && pos.startTime > lastTime) {
      // 计算正确播放时机
      final playTime = deviceTime + ((pos.startTime - time));
      tap(pos.beat, playTime);
      lastTime = pos.startTime;
    }
  }

  tap(double beat, double when) {
    final nowBeat = (beat % 4) + 1;
    if (nowBeat == 1.0) {
      final audio = audioContext.createBufferSource(synthesizerHigh);
      audio.connect(audioContext.destination);
      audio.start(when: when);

//      electronTap(true, playTime);
    }
    if ( [2.0,3.0,4.0].contains(nowBeat)) {
      final audio = audioContext.createBufferSource(synthesizerLow);
      audio.connect(audioContext.destination);
      audio.start(when: when);
//      electronTap(false, playTime);
    }
  }


  BeatPosPack getBeatPos(double time) {
    final mince = 4;
    final skipCount = beatSequence.where((v) => v.time <= time && v.skip).length;
    int i = 0;
    final index = beatSequence.indexWhere((v) {
      final nextIndex = (i++) + 1;
      if(beatSequence.length > nextIndex) {
        final n = beatSequence[nextIndex];
        return v.time <= time && n.time > time;
      }
      return false;
    });

    if(index == -1) {
      return null;
    }
    final current = beatSequence[index];
    final next = beatSequence[index + 1];
    if (current.skip) {
      return null;
    }

    final interval = next.time - current.time;
    final fp = ((time - current.time) / interval * mince).floor() / mince;
    final currentBeat = (index + fp) - skipCount;
    if (currentBeat < 0) { return null; }
    final currentBeatStartTime = (current.time + (interval * fp));
    return BeatPosPack(currentBeat, currentBeatStartTime);
  }


  initPath() async {
    synthesizerHigh = audioContext.decodeAudioFile(await loadAsset('synthesizer-high.wav'));
    synthesizerLow = audioContext.decodeAudioFile(await loadAsset('synthesizer-low.wav'));
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (player.duration != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: StreamBuilder<Duration>(
                    stream: player.onPosition,
                    builder: (context, snapshot) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("${player.position}/ ${player.duration}"),
                          LinearProgressIndicator(value: player.percentage),
                          Slider(
                            value: playerPosChange != null ? playerPosChange : player.percentage,
                            min: 0,
                            max: 1.0,
                            onChangeStart: (val) {
                              setState(() {
                                playerPosChange = val;
                              });
                            },
                            onChanged: (double val) {
                              setState(() {
                                playerPosChange = val;
                              });
                            },
                            onChangeEnd: (double val) {
                              setState(() {
                                playerPosChange = null;
                              });
                              player.seekTo(player.percentageToTime(val));
                              print(val);
                            },
                          ),
                          Text("速度 ${speed.toStringAsFixed(2)}"),
                          Slider(
                            value: speed,
                            min: 0.2,
                            max: 3.0,
                            onChanged: (double val) {
                              setState(() {
                                speed = val;
                              });
                              this.player.playbackRate = val;
                            },
                          ),
                        ],
                      );
                    }),
              ),
            RaisedButton(
                child: Text("播放新文件1"),
                onPressed: () async {
                  player.play(await loadAsset('music.mp3'));
                  setState(() {});
                }),
            RaisedButton(
                child: Text("播放新文件2"),
                onPressed: () async {
                  player.play(await loadAsset('music2.mp3'));
                  setState(() {});
                }),
            RaisedButton(
                child: Text("播放新文件3"),
                onPressed: () async {
                  player.play(await loadAsset('music3.mp3'));
                  setState(() {});
                }),
            RaisedButton(
                child: Text("播放新文件4"),
                onPressed: () async {
                  player.play(await loadAsset('music4.mp3'));
                  setState(() {});
                }),
            RaisedButton(
                child: Text("播放新文件5"),
                onPressed: () async {
                  player.play(await loadAsset('music5.mp3'));
                  setState(() {});
                }),
            RaisedButton(
                child: Text("播放新文件6"),
                onPressed: () async {
                  player.play(await loadAsset('music6.mp3'));
                  setState(() {});
                }),
            RaisedButton(
                child: Text("播放新文件7"),
                onPressed: () async {
                  player.play(await loadAsset('music7.mp3'));
                  setState(() {});
                }),
            RaisedButton(
                child: Text("暂停"),
                onPressed: () {
                  player.pause();
                  setState(() {});
                }),
            RaisedButton(
                child: Text("恢复"),
                onPressed: () {
                  player.resume();
                  setState(() {});
                }),
          ],
        ),
      ),
    );
  }
}
