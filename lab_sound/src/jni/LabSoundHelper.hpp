///
/// Created by Administrator on 2020/8/17.
///

#define DART_CALL __attribute__ ((visibility ("default"))) __attribute__ ((used))

#include "LabSound/LabSound.h"
#include "SoundTouchNode.h"
#include <thread>

using namespace lab;

template <typename Duration>
void Wait(Duration duration)
{
    std::this_thread::sleep_for(duration);
}

int bufferCount;
std::map<int,std::shared_ptr<AudioBus>> audioBuffers;

int nodeCount;
std::map<int,std::shared_ptr<AudioNode>> audioNodes;
int keepNode(std::shared_ptr<AudioNode> node){
    nodeCount++;
    audioNodes.insert(std::pair<int,std::shared_ptr<AudioNode>>(nodeCount,node));
    return nodeCount;
}

extern "C" DART_CALL
AudioContext* createRealtimeAudioContext(int channels,float sampleRate){
    AudioStreamConfig outputConfig = AudioStreamConfig();
    outputConfig.desired_channels = channels;
    outputConfig.desired_samplerate = sampleRate;
    auto context = MakeRealtimeAudioContext(outputConfig, AudioStreamConfig()).release();
    return context;
}

extern "C" DART_CALL
AudioContext* createOfflineAudioContext(int channels,float sampleRate,float timeMills){
    AudioStreamConfig offlineConfig = AudioStreamConfig();
    offlineConfig.desired_channels = channels;
    offlineConfig.desired_samplerate = sampleRate;
    offlineConfig.device_index = 0;
    auto context = MakeOfflineAudioContext(offlineConfig,timeMills).release();
    return context;
}

class BoolData{
private:
    bool data = false;
public:
    bool value(){
        return data;
    }
    void setValue(bool v){
        data = v;
    }
};

extern "C" DART_CALL
void startOfflineRendering(AudioContext* context,int recorderIndex,const char* file_path){
    RecorderNode* recorder = static_cast<RecorderNode*>(audioNodes.find(recorderIndex)->second.get());
    recorder->startRecording();

    BoolData* renderComplete = new BoolData();
    context->offlineRenderCompleteCallback = [recorderIndex,&context, &recorder,file_path,renderComplete]() {
        recorder->stopRecording();
        context->removeAutomaticPullNode(audioNodes.find(recorderIndex)->second);
        recorder->writeRecordingToWav(file_path);
        renderComplete->setValue(true);
    };

    context->startOfflineRendering();
    ((NullDeviceNode*)context->device().get())->joinRenderThread();
}

extern "C" DART_CALL
double currentTime(AudioContext* context){
    return context->currentTime();
}

extern "C" DART_CALL
float sampleRate(AudioContext* context){
    return context->sampleRate();
}

extern "C" DART_CALL
uint64_t currentSampleFrame(AudioContext* context){
    return context->currentSampleFrame();
}

extern "C" DART_CALL
int decodeAudioData(const char *file) {
    auto bus = MakeBusFromFile(file, true);
    bufferCount++;
    audioBuffers.insert(std::pair<int,std::shared_ptr<AudioBus>>(bufferCount,bus));
    return bufferCount;
}

extern "C" DART_CALL
void connect(AudioContext* context, int destination, int source) {
    std::shared_ptr<AudioNode> dst;
    if(destination == -1){
        dst = context->device();
    }else{
        dst = audioNodes.find(destination)->second;
    }
    context->connect(dst,audioNodes.find(source)->second,0,0);
}

extern "C" DART_CALL
void disconnect(AudioContext* context, int destination, int source) {
    std::shared_ptr<AudioNode> dst;
    if(destination == -1){
        dst = context->device();
    }else{
        dst = audioNodes.find(destination)->second;
    }
    context->disconnect(dst,audioNodes.find(source)->second,0,0);
}

/////////////////////
/// Node Creation ///
/////////////////////


extern "C" DART_CALL
int createRecorderNode(AudioContext* context,int channels,float sampleRate) {
    AudioStreamConfig offlineConfig = AudioStreamConfig();
    offlineConfig.desired_channels = channels;
    offlineConfig.desired_samplerate = sampleRate;
    offlineConfig.device_index = 0;
    auto recorder = std::make_shared<RecorderNode>(offlineConfig);
    context->addAutomaticPullNode(recorder);
    return keepNode(recorder);
}

extern "C" DART_CALL
int createAudioSampleNode(AudioContext* context,int busIndex) {
    auto sample = std::make_shared<SampledAudioNode>();
    ContextRenderLock r(context,"sample");
    sample->setBus(r,audioBuffers.find(busIndex)->second);
    return keepNode(sample);
}

extern "C" DART_CALL
int createSoundTouchNode(AudioContext* context,int busIndex) {
    auto node = std::make_shared<SoundTouchNode>();
    ContextRenderLock r(context,"sample");
    node->setBus(r,audioBuffers.find(busIndex)->second);
    return keepNode(node);
}

extern "C" DART_CALL
int createGain() {
    auto node = std::make_shared<GainNode>();
    return keepNode(node);
}

extern "C" DART_CALL
int AudioBuffer_numberOfChannels(int index){
    return static_cast<AudioBus*>(audioBuffers.find(index)->second.get())->numberOfChannels();
}

extern "C" DART_CALL
int AudioBuffer_length(int index){
    return static_cast<AudioBus*>(audioBuffers.find(index)->second.get())->length();
}

extern "C" DART_CALL
float AudioBuffer_sampleRate(int index){
    return static_cast<AudioBus*>(audioBuffers.find(index)->second.get())->sampleRate();
}



extern "C" DART_CALL
void SampledAudioNode_start(int index, double when) {
    static_cast<SampledAudioNode*>(audioNodes.find(index)->second.get())->start(when);
}

extern "C" DART_CALL
void SampledAudioNode_reset(AudioContext* context, int index) {
    ContextRenderLock r(context, "reset");
    static_cast<SampledAudioNode*>(audioNodes.find(index)->second.get())->reset(r);
}

extern "C" DART_CALL
void SampledAudioNode_startGrain(int index, double when,double offset) {
    static_cast<SampledAudioNode*>(audioNodes.find(index)->second.get())->startGrain(when,offset);
}

extern "C" DART_CALL
void SampledAudioNode_startGrain2(int index, double when,double offset,double duration) {
    static_cast<SampledAudioNode*>(audioNodes.find(index)->second.get())->startGrain(when,offset,duration);
}

extern "C" DART_CALL
float SampledAudioNode_duration(int index) {
    return static_cast<SampledAudioNode*>(audioNodes.find(index)->second.get())->duration();
}

extern "C" DART_CALL
double SampledAudioNode_virtualReadIndex(int index) {
    return static_cast<SampledAudioNode*>(audioNodes.find(index)->second.get())->virtualReadIndex();
}


extern "C" DART_CALL
AudioParam* SampledAudioNode_playbackRate(int index) {
    return static_cast<SampledAudioNode*>(audioNodes.find(index)->second.get())->playbackRate().get();
}

extern "C" DART_CALL
AudioParam* GainNode_gain(int index) {
    return static_cast<GainNode*>(audioNodes.find(index)->second.get())->gain().get();
}


extern "C" DART_CALL
AudioParam* SampledAudioNode_gain(int index) {
    return static_cast<SampledAudioNode*>(audioNodes.find(index)->second.get())->gain().get();
}

extern "C" DART_CALL
AudioParam* SampledAudioNode_detune(int index) {
    return static_cast<SampledAudioNode*>(audioNodes.find(index)->second.get())->detune().get();
}

extern "C" DART_CALL
void SampledAudioNode_stop(int index,double when) {
    static_cast<SampledAudioNode*>(audioNodes.find(index)->second.get())->stop(when);
}

extern "C" DART_CALL
int SampledAudioNode_hasFinished(int index) {
    return static_cast<SampledAudioNode*>(audioNodes.find(index)->second.get())->hasFinished();
}

extern "C" DART_CALL
int SampledAudioNode_isPlayingOrScheduled(int index) {
    return static_cast<SampledAudioNode*>(audioNodes.find(index)->second.get())->isPlayingOrScheduled();
}


//////////////////////
/// SoundTouchNode /// soundTouchNode
//////////////////////


extern "C" DART_CALL
void SoundTouchNode_start(int index, double when) {
    static_cast<SoundTouchNode*>(audioNodes.find(index)->second.get())->start(when);
}

extern "C" DART_CALL
void SoundTouchNode_startGrain(int index, double when,double offset) {
    static_cast<SoundTouchNode*>(audioNodes.find(index)->second.get())->startGrain(when,offset);
}

extern "C" DART_CALL
void SoundTouchNode_startGrain2(int index, double when,double offset,double duration) {
    static_cast<SoundTouchNode*>(audioNodes.find(index)->second.get())->startGrain(when,offset,duration);
}

extern "C" DART_CALL
float SoundTouchNode_duration(int index) {
    return static_cast<SoundTouchNode*>(audioNodes.find(index)->second.get())->duration();
}

extern "C" DART_CALL
AudioParam* SoundTouchNode_playbackRate(int index) {
    return static_cast<SoundTouchNode*>(audioNodes.find(index)->second.get())->playbackRate().get();
}

extern "C" DART_CALL
double SoundTouchNode_virtualReadIndex(int index) {
    return static_cast<SoundTouchNode*>(audioNodes.find(index)->second.get())->virtualReadIndex();
}

extern "C" DART_CALL
AudioParam* SoundTouchNode_gain(int index) {
    return static_cast<SoundTouchNode*>(audioNodes.find(index)->second.get())->gain().get();
}

extern "C" DART_CALL
AudioParam* SoundTouchNode_detune(int index) {
    return static_cast<SoundTouchNode*>(audioNodes.find(index)->second.get())->detune().get();
}

extern "C" DART_CALL
void SoundTouchNode_stop(int index,double when) {
    static_cast<SoundTouchNode*>(audioNodes.find(index)->second.get())->stop(when);
}

extern "C" DART_CALL
int SoundTouchNode_hasFinished(int index) {
    return static_cast<SoundTouchNode*>(audioNodes.find(index)->second.get())->hasFinished();
}

extern "C" DART_CALL
int SoundTouchNode_isPlayingOrScheduled(int index) {
    return static_cast<SoundTouchNode*>(audioNodes.find(index)->second.get())->isPlayingOrScheduled();
}


extern "C" DART_CALL
void SoundTouchNode_setPitch(int index, double value) {
    static_cast<SoundTouchNode*>(audioNodes.find(index)->second.get())->setPitch(value);
}

extern "C" DART_CALL
void SoundTouchNode_setTempo(int index, double value) {
    static_cast<SoundTouchNode*>(audioNodes.find(index)->second.get())->setTempo(value);
}




//////////////////
/// AudioParam ///
//////////////////
extern "C" DART_CALL
float AudioParam_value(AudioContext* context,AudioParam* param) {
    ContextRenderLock r(context,"param");
    return param->value(r);
}

extern "C" DART_CALL
void AudioParam_setValue(AudioParam* param,float value) {
    param->setValue(value);
}

extern "C" DART_CALL
void AudioParam_setValueCurveAtTime(AudioParam* param,float curve[],float time,float duration) {
    std::vector<float> curveVec;
    int length = sizeof(&curve)/sizeof(curve[0]);
    for(int i=0;i<length;i++){
        curveVec.push_back(curve[i]);
    }
    param->setValueCurveAtTime(curveVec,time,duration);
}

extern "C" DART_CALL
void AudioParam_setValueAtTime(AudioParam* param,float value,float time) {
    param->setValueAtTime(value,time);
}

extern "C" DART_CALL
void AudioParam_exponentialRampToValueAtTime(AudioParam* param,float value,float time) {
    param->exponentialRampToValueAtTime(value,time);
}

extern "C" DART_CALL
void AudioParam_linearRampToValueAtTime(AudioParam* param,float value,float time) {
    param->linearRampToValueAtTime(value,time);
}

extern "C" DART_CALL
void AudioParam_setTargetAtTime(AudioParam* param,float target,float time,float timeConstant) {
    param->setTargetAtTime(target,time,timeConstant);
}

extern "C" DART_CALL
void releaseContext(AudioContext* ctx) {
    delete ctx;
}

extern "C" DART_CALL
void releaseNode(int index){
    std::map<int,std::shared_ptr<AudioNode>>::iterator ite = audioNodes.find(index);
    if (ite != audioNodes.end()) {
        audioNodes.erase(index);
    }
}

extern "C" DART_CALL
void releaseBuffer(int index){
    std::map<int,std::shared_ptr<AudioBus>>::iterator ite = audioBuffers.find(index);
    if(ite != audioBuffers.end()){
        audioBuffers.erase(index);
    }
}

// extern "C" DART_CALL
// void releaseAllNode() {
//     for(auto node : audioNodes){
//         delete node.second.get();
//     }
// }

// extern "C" DART_CALL
// void releaseAllAudioBuffer() {
//     for(auto buffer : audioBuffers){
//         delete buffer.second.get();
//     }
// }

// extern "C" DART_CALL
// void allRelease(AudioContext* ctx){
//     delete ctx;
//     releaseAllNode();
//     releaseAllAudioBuffer();
//     nodeCount = 0;
//     bufferCount = 0;
//     audioBuffers.clear();
//     audioNodes.clear();
// }