import 'package:ffi/ffi.dart';
import 'dart:ffi';
import 'dart:io';

const bool inProduction = const bool.fromEnvironment("dart.vm.product");

String libFileName = 'libLabSound.so';
final DynamicLibrary labSoundLib = Platform.isAndroid
? DynamicLibrary.open(inProduction ? "libLabSound.so" : "libLabSound_d.so")
: DynamicLibrary.process();

final Pointer Function(
    int channels,
    double
    sampleRate) createRealtimeAudioContext = labSoundLib
    .lookup<NativeFunction<Pointer Function(Int32 channels, Float sampleRate)>>(
    "createRealtimeAudioContext")
    .asFunction();


final Pointer Function(int channels, double sampleRate, double timeMills) createOfflineAudioContext = labSoundLib
    .lookup<NativeFunction<Pointer Function(Int32 channels, Float sampleRate, Float timeMills)>>(
    "createOfflineAudioContext")
    .asFunction();

final void Function(Pointer ctx, int recorderIndex, Pointer<Utf8> path) startOfflineRendering = labSoundLib
    .lookup<NativeFunction<Void Function(Pointer ctx, Int32 recorderIndex, Pointer<Utf8> path)>>(
    "startOfflineRendering")
    .asFunction();


final double Function(Pointer context) currentTime = labSoundLib
    .lookup<NativeFunction<Double Function(Pointer)>>("currentTime")
    .asFunction();

final double Function(Pointer context) sampleRate = labSoundLib
    .lookup<NativeFunction<Float Function(Pointer)>>("sampleRate")
    .asFunction();

final int Function(Pointer context) currentSampleFrame = labSoundLib
    .lookup<NativeFunction<Uint64 Function(Pointer)>>("currentSampleFrame")
    .asFunction();

final int Function(Pointer<Utf8> path) decodeAudioData = labSoundLib
    .lookup<NativeFunction<Int32 Function(Pointer<Utf8>)>>("decodeAudioData")
    .asFunction();

final void Function(Pointer context, int dst, int src) connect = labSoundLib
    .lookup<
    NativeFunction<
        Void Function(
            Pointer context, Int32 dstIndex, Int32 srcIndex)>>("connect")
    .asFunction();

final void Function(Pointer context, int dst, int src) disconnect = labSoundLib
    .lookup<
    NativeFunction<
        Void Function(
            Pointer context, Int32 dstIndex, Int32 srcIndex)>>("disconnect")
    .asFunction();

/////////////////////
/// Node Creation ///
/////////////////////

final int Function(Pointer context, int channels, double sampleRate) createRecorderNode =
labSoundLib
    .lookup<NativeFunction<Int32 Function(Pointer context, Int32 channels, Float sampleRate)>>(
    "createRecorderNode")
    .asFunction();

final int Function(Pointer context, int bus) createAudioSampleNode =
labSoundLib
    .lookup<NativeFunction<Int32 Function(Pointer context, Int32 bus)>>(
    "createAudioSampleNode")
    .asFunction();

final int Function(Pointer context, int bus, double maxRate) createSoundTouchNode =
labSoundLib
    .lookup<NativeFunction<Int32 Function(Pointer context, Int32 bus, Double maxRate)>>(
    "createSoundTouchNode")
    .asFunction();

final int Function(Pointer context) createGain =
labSoundLib
    .lookup<NativeFunction<Int32 Function(Pointer context)>>(
    "createGain")
    .asFunction();



final int Function(int sampledAudioNode) AudioBufferNumberOfChannels = labSoundLib
    .lookup<NativeFunction<Int32 Function(Int32 busIndex)>>(
    "AudioBuffer_numberOfChannels")
    .asFunction();

final int Function(int sampledAudioNode) AudioBufferLength = labSoundLib
    .lookup<NativeFunction<Int32 Function(Int32 busIndex)>>(
    "AudioBuffer_length")
    .asFunction();

final double Function(int sampledAudioNode) AudioBufferSampleRate = labSoundLib
    .lookup<NativeFunction<Float Function(Int32 busIndex)>>(
    "AudioBuffer_sampleRate")
    .asFunction();


final void Function(Pointer context, int sampledAudioNode) SampledAudioNodeReset = labSoundLib
    .lookup<NativeFunction<Void Function(Pointer context, Int32 sampledAudioNode)>>(
    "SampledAudioNode_reset")
    .asFunction();

final void Function(int sampledAudioNode, double when) sampledAudioNodeStart = labSoundLib
    .lookup<NativeFunction<Void Function(Int32 sampledAudioNode, Double when)>>(
    "SampledAudioNode_start")
    .asFunction();

final void Function(int sampledAudioNode, double when, double offset) sampledAudioNodeStartGrain = labSoundLib
    .lookup<NativeFunction<Void Function(Int32 sampledAudioNode, Double when, Double offset)>>(
    "SampledAudioNode_startGrain")
    .asFunction();

final void Function(int sampledAudioNode, double when, double offset, double duration) sampledAudioNodeStartGrain2 = labSoundLib
    .lookup<NativeFunction<Void Function(Int32 sampledAudioNode, Double when, Double offset, Double duration)>>(
    "SampledAudioNode_startGrain2")
    .asFunction();

final double Function(int sampledAudioNode) sampledAudioNodeDuration = labSoundLib
    .lookup<NativeFunction<Float Function(Int32 sampledAudioNode)>>(
    "SampledAudioNode_duration")
    .asFunction();


final double Function(int sampledAudioNode) sampledAudioNodeVirtualReadIndex = labSoundLib
    .lookup<NativeFunction<Double Function(Int32 sampledAudioNode)>>(
    "SampledAudioNode_virtualReadIndex")
    .asFunction();


final Pointer Function(int sampledAudioNode) sampledAudioNodePlaybackRate = labSoundLib
    .lookup<NativeFunction<Pointer Function(Int32 sampledAudioNode)>>(
    "SampledAudioNode_playbackRate")
    .asFunction();


final Pointer Function(int sampledAudioNode) gainNodeGain = labSoundLib
    .lookup<NativeFunction<Pointer Function(Int32 nodeId)>>(
    "GainNode_gain")
    .asFunction();


final Pointer Function(int sampledAudioNode) sampledAudioNodeGain = labSoundLib
    .lookup<NativeFunction<Pointer Function(Int32 sampledAudioNode)>>(
    "SampledAudioNode_gain")
    .asFunction();

final Pointer Function(int sampledAudioNode) sampledAudioNodeDetune = labSoundLib
    .lookup<NativeFunction<Pointer Function(Int32 sampledAudioNode)>>(
    "SampledAudioNode_detune")
    .asFunction();


final void Function(int sampledAudioNode, double when) sampledAudioStop = labSoundLib
    .lookup<NativeFunction<Void Function(Int32 sampledAudioNode, Double when)>>(
    "SampledAudioNode_stop")
    .asFunction();

final int Function(int sampledAudioNode) sampledAudioNodeHasFinished = labSoundLib
    .lookup<NativeFunction<Int32 Function(Int32 sampledAudioNode)>>(
    "SampledAudioNode_hasFinished")
    .asFunction();

final int Function(int sampledAudioNode) sampledAudioNodeIsPlayingOrScheduled = labSoundLib
    .lookup<NativeFunction<Int32 Function(Int32 sampledAudioNode)>>(
    "SampledAudioNode_isPlayingOrScheduled")
    .asFunction();


//////////////////////
/// SoundTouchNode ///
//////////////////////


final void Function(Pointer context, int soundTouchNode) soundTouchNodeReset = labSoundLib
    .lookup<NativeFunction<Void Function(Pointer context, Int32 soundTouchNode)>>(
    "SoundTouchNode_reset")
    .asFunction();

final void Function(int soundTouchNode, double when) soundTouchNodeStart = labSoundLib
    .lookup<NativeFunction<Void Function(Int32 soundTouchNode, Double when)>>(
    "SoundTouchNode_start")
    .asFunction();

final void Function(int soundTouchNode, double when, double offset) soundTouchNodeStartGrain = labSoundLib
    .lookup<NativeFunction<Void Function(Int32 soundTouchNode, Double when, Double offset)>>(
    "SoundTouchNode_startGrain")
    .asFunction();

final void Function(int soundTouchNode, double when, double offset, double duration) soundTouchNodeStartGrain2 = labSoundLib
    .lookup<NativeFunction<Void Function(Int32 soundTouchNode, Double when, Double offset, Double duration)>>(
    "SoundTouchNode_startGrain2")
    .asFunction();

final double Function(int soundTouchNode) soundTouchNodeDuration = labSoundLib
    .lookup<NativeFunction<Float Function(Int32 soundTouchNode)>>(
    "SoundTouchNode_duration")
    .asFunction();


final double Function(int soundTouchNode) soundTouchNodeVirtualReadIndex = labSoundLib
    .lookup<NativeFunction<Double Function(Int32 soundTouchNode)>>(
    "SoundTouchNode_virtualReadIndex")
    .asFunction();


final Pointer Function(int soundTouchNode) soundTouchNodePlaybackRate = labSoundLib
    .lookup<NativeFunction<Pointer Function(Int32 soundTouchNode)>>(
    "SoundTouchNode_playbackRate")
    .asFunction();

final Pointer Function(int soundTouchNode) soundTouchNodeGain = labSoundLib
    .lookup<NativeFunction<Pointer Function(Int32 soundTouchNode)>>(
    "SoundTouchNode_gain")
    .asFunction();

final Pointer Function(int soundTouchNode) soundTouchNodeDetune = labSoundLib
    .lookup<NativeFunction<Pointer Function(Int32 soundTouchNode)>>(
    "SoundTouchNode_detune")
    .asFunction();


final void Function(int soundTouchNode, double when) soundTouchNodeStop = labSoundLib
    .lookup<NativeFunction<Void Function(Int32 soundTouchNode, Double when)>>(
    "SoundTouchNode_stop")
    .asFunction();

final int Function(int soundTouchNode) soundTouchNodeHasFinished = labSoundLib
    .lookup<NativeFunction<Int32 Function(Int32 soundTouchNode)>>(
    "SoundTouchNode_hasFinished")
    .asFunction();

final int Function(int soundTouchNode) soundTouchNodeIsPlayingOrScheduled = labSoundLib
    .lookup<NativeFunction<Int32 Function(Int32 soundTouchNode)>>(
    "SoundTouchNode_isPlayingOrScheduled")
    .asFunction();




final void Function(int soundTouchNode, double value) soundTouchNodeSetRate = labSoundLib
    .lookup<NativeFunction<Void Function(Int32, Double)>>(
    "SoundTouchNode_setRate")
    .asFunction();

final void Function(int soundTouchNode, double value) soundTouchNodeSetPitch = labSoundLib
    .lookup<NativeFunction<Void Function(Int32, Double)>>(
    "SoundTouchNode_setPitch")
    .asFunction();

final void Function(int soundTouchNode, double value) soundTouchNodeSetTempo = labSoundLib
    .lookup<NativeFunction<Void Function(Int32, Double)>>(
    "SoundTouchNode_setTempo")
    .asFunction();



final double Function(Pointer context, Pointer param) audioParamValue = labSoundLib
    .lookup<NativeFunction<Float Function(Pointer context, Pointer param)>>(
    "AudioParam_value")
    .asFunction();

final void Function(Pointer param, double value) audioParamSetValue = labSoundLib
    .lookup<NativeFunction<Void Function(Pointer param, Float value)>>(
    "AudioParam_setValue")
    .asFunction();

//final void Function(Pointer param, Pointer<Float> value, double time, double duration) paramSetValueCurveAtTime = labSoundLib
//    .lookup<NativeFunction<Void Function(Pointer param, Pointer<Float> value, Float, Float)>>(
//    "AudioParam_setValueCurveAtTime")
//    .asFunction();

final void Function(Pointer param, double value, double time) audioParamSetValueAtTime = labSoundLib
    .lookup<NativeFunction<Void Function(Pointer param, Float value, Float)>>(
    "AudioParam_setValueAtTime")
    .asFunction();

final void Function(Pointer param, double value, double time) audioParamExponentialRampToValueAtTime = labSoundLib
    .lookup<NativeFunction<Void Function(Pointer param, Float value, Float)>>(
    "AudioParam_exponentialRampToValueAtTime")
    .asFunction();

final void Function(Pointer param, double value, double time) audioParamLinearRampToValueAtTime = labSoundLib
    .lookup<NativeFunction<Void Function(Pointer param, Float value, Float)>>(
    "AudioParam_linearRampToValueAtTime")
    .asFunction();

final void Function(Pointer param, double value, double time, double timeConstant) audioParamSetTargetAtTime = labSoundLib
    .lookup<NativeFunction<Void Function(Pointer param, Float value, Float, Float)>>(
    "AudioParam_setTargetAtTime")
    .asFunction();

final void Function(Pointer ctx) releaseContext = labSoundLib
    .lookup<NativeFunction<Void Function(Pointer)>>(
    "releaseContext")
    .asFunction();

final void Function(int nodeId) releaseNode = labSoundLib
    .lookup<NativeFunction<Void Function(Int32)>>(
    "releaseNode")
    .asFunction();

final void Function(int nodeId) releaseBuffer = labSoundLib
    .lookup<NativeFunction<Void Function(Int32)>>(
    "releaseBuffer")
    .asFunction();


final void Function() releaseAllNode = labSoundLib
    .lookup<NativeFunction<Void Function()>>(
    "releaseAllNode")
    .asFunction();


final void Function() releaseAllAudioBuffer = labSoundLib
    .lookup<NativeFunction<Void Function()>>(
    "releaseAllAudioBuffer")
    .asFunction();


final void Function() allRelease = labSoundLib
    .lookup<NativeFunction<Void Function()>>(
    "allRelease")
    .asFunction();




