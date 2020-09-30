import 'dart:async';

import 'lab_sound.dart';

enum LabPlayerStatus {
  pause, playing, ended,
}

class LabPlayer {
  AudioContext audioContext;
  AudioPlayerNode _player;
  set player (AudioPlayerNode v) {
    _subscriptionPosition?.cancel();
    _subscriptionEnded?.cancel();
    _player = v;
    if(_player == null) return;
    if(_playbackRate != 1.0) {
      playbackRate = playbackRate;
    }
    _subscriptionPosition = _player.onPosition.listen((event) {
      this._onPositionController.add(event);
    });
    _subscriptionEnded = _player.onEnded.listen((event) {
      final isOver = status == LabPlayerStatus.playing;
      status = LabPlayerStatus.ended;
      this._onEndedController.add(isOver);
      if(isOver) {
        _onPositionController.add(Duration.zero);
      }
    });
    posWaitingPlayerSwitch = false;
  }
  AudioPlayerNode get player {
    return _player;
  }
  GainNode playerGainNode;
  AudioBus audioData;
  AudioBus readyAudioData;
  GainNode masterGainNode;
  double _volume = 1.0;
  double crossfadeTime = 0.3;
  bool get playing => status == LabPlayerStatus.playing;

  AudioPlayerNode createBufferSource(AudioBus audio) {
//    return this.audioContext.createBufferSource(audio);
    return this.audioContext.createSoundTouch(audio, maxRate: 2.0);
  }


  bool get playerPosIsZero => (player?.position ?? Duration(milliseconds: 0)).inMilliseconds == 0;

  Duration get position {
    final pos = ( (playing && !playerPosIsZero && !posWaitingPlayerSwitch ) ? player?.position : _startPositionLast)?? Duration.zero;
    if(pos.inMilliseconds < 10.0) print("pos<10: $pos; playing: $playing playerPosIsZero:$playerPosIsZero _startPositionLast: $_startPositionLast");
    return pos;
  }
  Duration get duration => player?.duration ?? Duration(milliseconds: 0);

  bool posWaitingPlayerSwitch = false;
  Duration _startPosition;
  Duration _startPositionLast = Duration.zero;
  set startPosition(Duration v) {
    _startPosition = v;
    if(v.inMilliseconds > 0) {
      _startPositionLast = v;
    }
  }
  Duration get startPosition => _startPosition;

  double _playbackRate = 1.0;
  double get playbackRate => _playbackRate;
  set playbackRate(double val) {
    print("playing is SoundTouchNode: ${playing is SoundTouchNode}");
    player?.rate = val;
    _playbackRate = val;
  }

  double get percentage => (this.duration?.inMilliseconds ?? 0) == 0 ? 0 : this.position.inMilliseconds / this.duration.inMilliseconds;

  Duration percentageToTime(double per) => Duration(milliseconds: (this.duration.inMilliseconds * per).toInt());

  LabPlayerStatus _status = LabPlayerStatus.pause;
  LabPlayerStatus get status {
    return this._status;
  }
  set status(LabPlayerStatus v) {
    this._status = v;
    _onStatusController.add(v);
  }
  StreamController<LabPlayerStatus> _onStatusController = StreamController.broadcast();
  Stream<LabPlayerStatus> get onStatus => _onStatusController.stream;

  StreamSubscription _subscriptionEnded;
  StreamController<bool> _onEndedController = StreamController.broadcast();
  Stream<bool> get onEnded => _onEndedController.stream;

  StreamSubscription _subscriptionPosition;
  StreamController<Duration> _onPositionController = StreamController.broadcast();
  Stream<Duration> get onPosition => _onPositionController.stream;

  LabPlayer({ AudioContext audioContext }) {
    this.audioContext = audioContext ?? AudioContext(initSampleRate: 48000.0, channels: 2);
    this.masterGainNode = this.audioContext.createGainNode();
    this.masterGainNode.connect(this.audioContext.destination);
    _volume = this.masterGainNode.gain.value;
  }

  double get volume => _volume;
  set volume (double value) {
    this._volume = value;
    masterGainNode.gain.setValue(value);
  }

  loadFile(String path) {
    if(readyAudioData != null) {
      readyAudioData.dispose();
    }
    this.readyAudioData = this.audioContext.decodeAudioFile(path);
  }

  play(String path) {
    if(playing) return;
    loadFile(path);
    if (readyAudioData != null) {
      playFromBus(readyAudioData);
    }
  }

  stop() {
    final oldPlayer = player;
    final oldPlayerGainNode = playerGainNode;
    if(playing) {
      if(crossfadeTime > 0.1 && playerGainNode != null && player != null) {
        final startTime = this.audioContext.currentTime + 0.1;
        oldPlayerGainNode.gain.setValueAtTime(oldPlayerGainNode.gain.value, startTime);
        oldPlayerGainNode.gain.exponentialRampToValueAtTime(
            0.001, startTime + crossfadeTime);
        oldPlayer?.stop(when: startTime + crossfadeTime);
        if(oldPlayer?.hasFinished) {
          oldPlayer?.dispose();
          oldPlayerGainNode?.dispose();
        } else {
          oldPlayer?.onEnded?.listen((event) {
            oldPlayer?.dispose();
            oldPlayerGainNode?.dispose();
          });
        }
      } else {
        oldPlayer?.stop(when: 0);
        oldPlayer?.dispose();
        oldPlayerGainNode?.dispose();
      }
    }else {
      oldPlayer?.dispose();
      oldPlayerGainNode?.dispose();
    }
    player = null;
    playerGainNode = null;
  }

  playFromBus(AudioBus bus) {
    final oldPlayer = player;
    final oldGainNode = playerGainNode;
    final newPlayer = createBufferSource(bus);
    final newGainNode = this.audioContext.createGainNode();
    newPlayer.connect(newGainNode);
    newGainNode.connect(this.masterGainNode);
    player = newPlayer;
    playerGainNode = newGainNode;
    _onPositionController.add(Duration.zero);
    if(crossfadeTime > 0.1 && playerGainNode != null) {
      final startTime = this.audioContext.currentTime;
      final oldEndTime = this.audioContext.currentTime + crossfadeTime;
      newGainNode.gain.setValue(0);
      newGainNode.gain.setValueAtTime(0.001, startTime + 0.1 );
      newGainNode.gain.exponentialRampToValueAtTime(1.0, oldEndTime);
      newPlayer.start(when: startTime);
      if(oldPlayer != null) {
        oldGainNode.gain.setValueAtTime(oldGainNode.gain.value, startTime + 0.1);
        oldGainNode.gain.exponentialRampToValueAtTime(0.0, oldEndTime);
        oldPlayer?.stop(when: oldEndTime + 2.0);
        if(oldPlayer?.hasFinished) {
          oldPlayer?.dispose();
        } else {
          oldPlayer?.onEnded?.listen((event) {
            oldPlayer?.dispose();
          });
        }
      }
    }else {
      newPlayer.start();
      oldPlayer?.stop();
      oldPlayer?.dispose();
    }
    status = LabPlayerStatus.playing;
    startPosition = Duration.zero;
  }

  resume() {
    if(player == null) return;

    if(crossfadeTime > 0.1 && playerGainNode != null) {
      final startTime = this.audioContext.currentTime + 0.1;
      playerGainNode.gain.setValueAtTime(0.001, startTime);
      playerGainNode.gain.exponentialRampToValueAtTime(1.0, startTime + crossfadeTime);
    }
    if(startPosition != null) {
      posWaitingPlayerSwitch = true;
      final oldPlayer = player;
      final newPlayer = createBufferSource(this.player.resource);
      newPlayer.connect(playerGainNode);
      newPlayer.start(when: 0, offset: startPosition.inMilliseconds / 1000);
      player = newPlayer;
      oldPlayer.dispose();
    } else {
      player.start();
    }
    status = LabPlayerStatus.playing;
  }

  pause() {
    startPosition = player.position;
    if(crossfadeTime > 0.1 && playerGainNode != null) {
      final startTime = this.audioContext.currentTime + 0.1;
      playerGainNode.gain.setValueAtTime(playerGainNode.gain.value, startTime);
      playerGainNode.gain.exponentialRampToValueAtTime(
          0.001, startTime + crossfadeTime);
      player.stop(when: startTime + crossfadeTime);
    } else {
      player.stop(when: 0);
    }
    status = LabPlayerStatus.pause;
  }

  seekTo(Duration pos) {
    posWaitingPlayerSwitch = true;
    startPosition = pos;
    if(player == null) return;
    if(status == LabPlayerStatus.playing) {
      if(crossfadeTime > 0.1 && playerGainNode != null) {
        final oldPlayer = player;
        final oldGainNode = playerGainNode;
        final newPlayer = createBufferSource(this.player.resource);
        final newGainNode = this.audioContext.createGainNode();
        newPlayer.connect(newGainNode);
        newGainNode.connect(this.masterGainNode);
        final startTime = this.audioContext.currentTime + 0.2;
        final oldEndTime = this.audioContext.currentTime + crossfadeTime;
        newGainNode.gain.setValue(0);
        newGainNode.gain.setValueAtTime(0.001, startTime );
        newGainNode.gain.exponentialRampToValueAtTime(1.0, oldEndTime);
        newPlayer.start(when: startTime, offset: pos.inMilliseconds / 1000);
        player = newPlayer;
        playerGainNode = newGainNode;
        oldGainNode.gain.setValueAtTime(oldGainNode.gain.value, startTime);
        oldGainNode.gain.exponentialRampToValueAtTime(0.0, oldEndTime);
        oldPlayer?.stop(when: oldEndTime);
        oldPlayer?.onEnded?.listen((event) {
          oldPlayer?.dispose();
//        oldGainNode?.dispose();
        });
      } else {
        player.start(when: 0, offset: pos.inMilliseconds / 1000);
      }
      status = LabPlayerStatus.playing;
    }else {
      startPosition = pos;
      status = LabPlayerStatus.pause;
    }
    startPosition = Duration.zero;
  }

  dispose() {
    player?.stop();
    player?.dispose();
    _subscriptionPosition?.cancel();
    _subscriptionEnded?.cancel();
    _onEndedController?.close();
    _onPositionController?.close();
    _onStatusController?.close();
  }

}