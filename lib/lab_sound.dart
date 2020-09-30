import 'dart:async';

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'dart:ffi'; // For FFI
import 'binding.dart' as lab;

class AudioContext {
  final Pointer pointer;
  final double initSampleRate;
  final int channels;
  final bool offline;

  double get correctionRate => initSampleRate / 24000.0;

  double correctionTime(double time) {
    return time * correctionRate;
  }

  AudioContext(
      {this.offline = false, this.initSampleRate = 24000.0, this.channels = 2, double timeMills})
      : pointer = (offline
            ? lab.createOfflineAudioContext(channels, initSampleRate, timeMills)
            : lab.createRealtimeAudioContext(channels, initSampleRate));

  double get currentTime {
    return lab.currentTime(this.pointer) / correctionRate;
  }

  double get sampleRate {
    return lab.sampleRate(this.pointer);
  }

  int get currentSampleFrame {
    return lab.currentSampleFrame(this.pointer);
  }

  connect(AudioNode dst, AudioNode src) {
    lab.connect(this.pointer, dst.nodeId, src.nodeId);
  }

  disconnect(AudioNode dst, AudioNode src) {
    lab.disconnect(this.pointer, dst.nodeId, src.nodeId);
  }

  AudioBus decodeAudioFile(String path, {audoDispose = true}) {
    return AudioBus(path, audoDispose: audoDispose);
  }

  AudioSampleNode createBufferSource(AudioBus audio) {
    return AudioSampleNode(this, audio);
  }
  SoundTouchNode createSoundTouch(AudioBus audio, {double maxRate = 2.0}) {
    return SoundTouchNode(this, audio, maxRate: maxRate);
  }

  RecorderNode createRecorderNode() {
    return RecorderNode(this, this.channels, this.sampleRate);
  }

  GainNode createGainNode() {
    return GainNode(this);
  }

  startOfflineRendering(String filePath, RecorderNode recorder) {
    lab.startOfflineRendering(this.pointer, recorder.nodeId, Utf8.toUtf8(filePath));
  }

  // 音频渲染设备;
  AudioNode get destination => AudioNode()..nodeId = -1;

  /// 关闭一个音频环境, 释放任何正在使用系统资源的音频。
  dispose() {
    lab.releaseContext(this.pointer);
  }
}

class AudioBus {
  int resourceId;
  Set<AudioNode> usedNode = Set();
  String filePath;
  bool audoDispose;

  AudioBus(this.filePath , {this.audoDispose = false}) {
    resourceId = lab.decodeAudioData(Utf8.toUtf8(filePath));
  }
  lock(AudioNode node) {
    print("$this 节点占用 $node");
    usedNode.add(node);
  }
  unlock(AudioNode node) {
    usedNode.remove(node);
    print("$this 节点解锁 $node, 剩余: $usedNode, audoDispose: ${audoDispose}");
    if(usedNode.length == 0 && audoDispose) {
      print("$this 销毁！！！");
      this.dispose();
    }
  }
  dispose() {
    lab.releaseBuffer(this.resourceId);
  }
  int get numberOfChannels => lab.AudioBufferNumberOfChannels(this.resourceId);
  int get length => lab.AudioBufferLength(this.resourceId);
  double get sampleRate => lab.AudioBufferSampleRate(this.resourceId);
  Duration get duration => Duration(milliseconds: (this.length / this.sampleRate * 1000).toInt());
  toString() {
    return "AudioBus<$resourceId>";
  }
}

class AudioNode {
  int nodeId;
  AudioContext ctx;

  List<AudioNode> Linked = [];

  connect(AudioNode dst) {
    Linked.add(dst);
    this.ctx.connect(dst, this);
  }
  disconnect(AudioNode dst) {
    Linked.remove(dst);
    this.ctx.disconnect(dst, this);
  }
  disconnectAll() {
    Linked.forEach((element) {
      this.ctx.disconnect(element, this);
    });
    Linked.clear();
  }
  dispose() {
    this.disconnectAll();
    lab.releaseNode(this.nodeId);
  }
}

class RecorderNode extends AudioNode {
  final int channels;
  final double sampleRate;
  RecorderNode(AudioContext ctx, this.channels, this.sampleRate){
    this.nodeId = lab.createRecorderNode(ctx.pointer, channels, sampleRate);
  }
}

class GainNode extends AudioNode {
  GainNode(AudioContext ctx) {
    this.ctx = ctx;
    this.nodeId = lab.createGain(ctx.pointer);
//    print(lab.gainNodeGain(this.nodeId));
    this.gain = AudioParam(this.ctx, lab.gainNodeGain(this.nodeId));
  }
  AudioParam gain;
}

class AudioParam {
  AudioContext ctx;
  final Pointer paramPointer;
  AudioParam(this.ctx, this.paramPointer);
  double get value => lab.audioParamValue(this.ctx.pointer, paramPointer);
  setValue(double value) {
    lab.audioParamSetValue(paramPointer, value);
  }
  setValueCurveAtTime(List<double> values, double time, double duration) {
    //todo
  }
  exponentialRampToValueAtTime(double value, double time) {
    lab.audioParamExponentialRampToValueAtTime(paramPointer, value, this.ctx.correctionTime(time));
  }
  linearRampToValueAtTime(double value, double time) {
    lab.audioParamLinearRampToValueAtTime(paramPointer, value, this.ctx.correctionTime(time));
  }
  setValueAtTime(double value, double time) {
    lab.audioParamSetValueAtTime(paramPointer, value, this.ctx.correctionTime(time));
  }
  setTargetAtTime(double value, double time, double timeConstant) {
    lab.audioParamSetTargetAtTime(paramPointer, value, this.ctx.correctionTime(time), timeConstant);
  }

}

abstract class AudioPlayerNode extends AudioNode {
  AudioBus resource;
  AudioParam playbackRate;
  AudioParam gain;
  AudioParam detune;
  Stream onEnded;
  Stream<Duration> onPosition;
  bool hasFinished;
  double virtualReadIndex;
  Duration position;
  Duration duration;

  double pitch;
  double tempo;
  double rate;

  start({double when, double offset, double duration});
  stop({double when});
  reset();
}

class AudioSampleNode extends AudioPlayerNode {
  AudioBus resource;
  AudioSampleNode(AudioContext ctx, AudioBus audio) {
    this.ctx = ctx;
    this.resource = audio;
    this.nodeId = lab.createAudioSampleNode(ctx.pointer, audio.resourceId);
    this.resource.lock(this);
    playbackRate = AudioParam(this.ctx, lab.sampledAudioNodePlaybackRate(this.nodeId));
    gain = AudioParam(this.ctx, lab.sampledAudioNodeGain(this.nodeId));
    detune = AudioParam(this.ctx, lab.sampledAudioNodeDetune(this.nodeId));
  }

  AudioParam playbackRate;
  AudioParam gain;
  AudioParam detune;

  StreamController _onEndedController = StreamController.broadcast();
  Stream get onEnded => _onEndedController.stream;

  StreamController<Duration> _onPositionController = StreamController.broadcast();
  Stream<Duration> get onPosition => _onPositionController.stream;

  Timer _checkTimer;
  _startCheckTimer(){
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic( Duration( milliseconds: 200 ), ( timer ) {
//      print("this.position ${this.position} - ${this.duration}");
      _onPositionController.add(this.position);
      if(this.hasFinished){
        _checkTimer.cancel();
        _checkTimer = null;
        _onEndedController.add(null);
      }
    });
  }

  bool get hasFinished => lab.sampledAudioNodeHasFinished(this.nodeId) != 0;
  double get virtualReadIndex => lab.sampledAudioNodeVirtualReadIndex(this.nodeId);
  Duration get position => Duration(milliseconds: (this.virtualReadIndex / this.resource.sampleRate * 1000).toInt());
  Duration get duration => this.resource.duration;

  start({double when, double offset, double duration}) {
    if(when != null && offset != null && duration != null) {
      lab.sampledAudioNodeStartGrain2(this.nodeId, ctx.correctionTime(when), offset, duration);
    }else if(when != null && offset != null) {
      lab.sampledAudioNodeStartGrain(this.nodeId, ctx.correctionTime(when), offset);
    }else{
      lab.sampledAudioNodeStart(this.nodeId, ctx.correctionTime(when ?? 0.0));
    }
    _startCheckTimer();
  }
  stop({double when}) {
    lab.soundTouchNodeStop(this.nodeId, ctx.correctionTime(when ?? 0));
  }
  reset() {
    lab.SampledAudioNodeReset(this.ctx.pointer, this.nodeId);
  }
  @override
  dispose() {
    this.resource.unlock(this);
    _onPositionController?.close();
    _onEndedController?.close();
    _checkTimer?.cancel();
    return super.dispose();
  }

  toString() {
    return "AudioSampleNode<${nodeId}>";
  }

}

class SoundTouchNode extends AudioPlayerNode {
  AudioBus resource;
  SoundTouchNode(AudioContext ctx, AudioBus audio, {bool disposable = false, double maxRate = 2.0 }) {
    this.ctx = ctx;
    this.resource = audio;
    this.nodeId = lab.createSoundTouchNode(ctx.pointer, audio.resourceId, maxRate);
    this.pitch = 1.0;
    this.tempo = 1.0;
    this.rate = 1.0;
    playbackRate = AudioParam(this.ctx, lab.soundTouchNodePlaybackRate(this.nodeId));
    gain = AudioParam(this.ctx, lab.soundTouchNodeGain(this.nodeId));
    if (disposable) {
      onEnded.listen((event) {
        this.dispose();
      });
    }
  }
  AudioParam playbackRate;
  AudioParam gain;
  AudioParam detune;

  double _pitch = 1.0;
  double _tempo = 1.0;
  double _rate = 1.0;

  double get pitch => _pitch;
  double get tempo => _tempo;
  double get rate => _rate;


  set pitch (double v) {
    _pitch = v;
    lab.soundTouchNodeSetPitch(this.nodeId, v);
  }
  set tempo (double v) {
    _tempo = v;
    lab.soundTouchNodeSetTempo(this.nodeId, v);
  }
  set rate (double v) {
    _rate = v;
    lab.soundTouchNodeSetRate(this.nodeId, v);
  }


  StreamController _onEndedController = StreamController.broadcast();
  Stream get onEnded => _onEndedController.stream;

  StreamController<Duration> _onPositionController = StreamController.broadcast();
  Stream<Duration> get onPosition => _onPositionController.stream;

  Timer _checkTimer;
  _startCheckTimer(){
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic( Duration( milliseconds: 200 ), ( timer ) {
//      print("this.position ${this.position} - ${this.duration}");
      _onPositionController.add(this.position);
      if(this.hasFinished){
        _checkTimer.cancel();
        _checkTimer = null;
        _onEndedController.add(null);
      }
    });
  }

  bool get hasFinished => lab.soundTouchNodeHasFinished(this.nodeId) != 0;

  double get virtualReadIndex => lab.soundTouchNodeVirtualReadIndex(this.nodeId);
  Duration get position => Duration(milliseconds: (this.virtualReadIndex / this.resource.sampleRate * 1000).toInt());
  Duration get duration => this.resource.duration;

  start({double when, double offset, double duration}) {
    if(when != null && offset != null && duration != null) {
      lab.soundTouchNodeStartGrain2(this.nodeId, ctx.correctionTime(when), offset, duration);
    }else if(when != null && offset != null) {
      lab.soundTouchNodeStartGrain(this.nodeId, ctx.correctionTime(when), offset);
    }else{
      lab.soundTouchNodeStart(this.nodeId, ctx.correctionTime(when ?? 0.0));
    }
    _startCheckTimer();
  }
  stop({double when}) {
    lab.soundTouchNodeStop(this.nodeId, ctx.correctionTime(when ?? 0));
  }
  reset() {
    lab.SampledAudioNodeReset(this.ctx.pointer, this.nodeId);
  }
  @override
  dispose() {
    _onPositionController?.close();
    _onEndedController?.close();
    _checkTimer?.cancel();
    return super.dispose();
  }

  onEndedDispose() {
    if(hasFinished) {
      this.dispose();
    } else {
      this.onEnded.listen((event) {
        this.dispose();
      });
    }
  }

}

