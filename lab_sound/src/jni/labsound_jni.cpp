//
// Created by ZZK on 2020/8/15.
//


#include <jni.h>

#include "LabSound/LabSound.h"
#include "LabSoundHelper.hpp"

using namespace lab;

void* speedUp(void* arg){
}

int speedUpNode;

extern "C"
JNIEXPORT void JNICALL
Java_dev_zzksoft_labsound_LabSound_main(JNIEnv *env, jobject thiz,jstring inFile,jstring outFile) {

    auto musicClip = decodeAudioData(env->GetStringUTFChars(inFile, 0));
//    auto context = createRealtimeAudioContext(2,44100);
    auto context = createRealtimeAudioContext(2,44100);

    int soundTouchNode1 = speedUpNode = createSoundTouchNode(context,musicClip, 3.0);
//    int soundTouchNode2 = createSoundTouchNode(context,musicClip);

    connect(context,-1,soundTouchNode1);
//    connect(context,-1,soundTouchNode2);

    SoundTouchNode_start(soundTouchNode1,1.0f);
//    SoundTouchNode_start(soundTouchNode2,3.0f);

    pthread_t t1;
    pthread_create(&t1,NULL,[](void* arg) -> void* {
        double speed = 1.0;
        double pitch = 0.0;
        while(speed < 1.5){
            std::this_thread::sleep_for(std::chrono::milliseconds(400));
            speed += 0.05;
            pitch += 0.5;
//            SoundTouchNode_setTempo(*((int*)arg),speed);
//            SoundTouchNode_setPitch(*((int*)arg),pitch);
        }
        pthread_exit(NULL);
        },&speedUpNode);
}

extern "C"
JNIEXPORT jlong JNICALL
Java_dev_zzksoft_labsound_LabSound_createContext(JNIEnv *env, jobject thiz) {
    return reinterpret_cast<jlong>(createRealtimeAudioContext(2,44100));
}

extern "C"
JNIEXPORT jint JNICALL
Java_dev_zzksoft_labsound_LabSound_loadAudioData(JNIEnv *env, jobject thiz, jstring path) {
    return decodeAudioData(env->GetStringUTFChars(path, 0));
}

extern "C"
JNIEXPORT jint JNICALL
Java_dev_zzksoft_labsound_LabSound_createAudioNode(JNIEnv *env, jobject thiz, jlong context,
                                                   jint bus_index) {
    return createAudioSampleNode(reinterpret_cast<AudioContext *>(context),bus_index);
}

extern "C"
JNIEXPORT void JNICALL
Java_dev_zzksoft_labsound_LabSound_start(JNIEnv *env, jobject thiz, jint audio_index,
                                         jdouble when) {
    SoundTouchNode_start(audio_index,when);
}

extern "C"
JNIEXPORT void JNICALL
Java_dev_zzksoft_labsound_LabSound_connectSample2Device(JNIEnv *env, jobject thiz, jlong context,
                                                        jint audio_index) {
    connect(reinterpret_cast<AudioContext *>(context),-1,audio_index);
}

JNIEnv* jniEnv;
jmethodID run;
jobject callbackObject;

void callRun(){
    jniEnv->CallVoidMethod(callbackObject,run);
}

extern "C"
JNIEXPORT void JNICALL
Java_dev_zzksoft_labsound_LabSound_setOnEnded(JNIEnv *env, jobject thiz, jint audio_index,
                                              jobject callback) {
    jniEnv = env;
    run = env->GetMethodID(env->GetObjectClass(callback),"run", "()V");
    callbackObject = callback;
}

extern "C"
JNIEXPORT jfloat JNICALL
Java_dev_zzksoft_labsound_LabSound_playbackRate(JNIEnv *env, jobject thiz, jlong context,
                                                jint audio_index) {
    ContextRenderLock r(reinterpret_cast<AudioContext *>(context), "");
    return SampledAudioNode_playbackRate(audio_index)->value(r);
}

extern "C"
JNIEXPORT jlong JNICALL
Java_dev_zzksoft_labsound_LabSound_createOfflineContext(JNIEnv *env, jobject thiz) {
    return reinterpret_cast<jlong>(createOfflineAudioContext(2,44100,10000));
}

extern "C"
JNIEXPORT void JNICALL
Java_dev_zzksoft_labsound_LabSound_startOfflineRender(JNIEnv *env, jobject thiz, jlong ctx,
                                                      jstring s) {
    //startOfflineRendering(reinterpret_cast<AudioContext *>(ctx),env->GetStringUTFChars(s, 0));
}


extern "C"
JNIEXPORT jint JNICALL
Java_dev_zzksoft_labsound_LabSound_createSoundTouch(JNIEnv *env, jobject thiz, jlong context,
                                                    jint bus_index) {
    return createSoundTouchNode(reinterpret_cast<AudioContext *>(context),bus_index, 3.0);
}