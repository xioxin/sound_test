
#include <jni.h>
#include <android/log.h>
#include <stdexcept>
#include <string>
#include <iostream>

using namespace std;

#include "SoundTouch.h"
#include "SoundStretch/WavFile.h"

static string _errMsg = "";


#define DLL_PUBLIC __attribute__ ((visibility ("default")))
#define BUFF_SIZE 8192

using namespace soundtouch;

class MusicTask;

static MusicTask* current = nullptr;

class MusicTask{
private:
    bool stopped = false;
    WavInFile* inFile;
    jfloatArray sampleData;
    jmethodID method;

public :
    MusicTask(){}
    int play(SoundTouch *pSoundTouch,const char* inputFile,JNIEnv* env,jobject object){
        try
        {
            int nSamples;
            int nChannels;
            int buffSizeSamples;
            SAMPLETYPE sampleBuffer[BUFF_SIZE];

            sampleData = env->NewFloatArray(BUFF_SIZE);
            method = env->GetMethodID(env->GetObjectClass(object),"onGetSampleData","(Z[FI)V");

            // 打开源文件
            inFile = new WavInFile(inputFile);
            int sampleRate = inFile->getSampleRate();
            nChannels = inFile->getNumChannels();

            pSoundTouch->setSampleRate(sampleRate);
            pSoundTouch->setChannels(nChannels);

            assert(nChannels > 0);
            buffSizeSamples = BUFF_SIZE / nChannels;

            // 处理从源文件中读取的音频
            while (inFile->eof() == 0){
                if(cantContinue())
                    break;

                int num;
                // 从源文件中读取一块数据
                num = inFile->read(sampleBuffer, BUFF_SIZE);

                nSamples = num / nChannels;

                // 将音频提交给SoundTouch处理进程
                pSoundTouch->putSamples(sampleBuffer, nSamples);

                do{
                    if(cantContinue())
                        break;

                    nSamples = pSoundTouch->receiveSamples(sampleBuffer, buffSizeSamples);
                    passResultBuffer(env,object,sampleBuffer,nSamples * nChannels);
                } while (nSamples != 0);
            }

            // 源文件处理完毕, 释放剩余的在SoundTouch进程的数据
            pSoundTouch->flush();
            if(!stopped)
                env->CallVoidMethod(object,env->GetMethodID(env->GetObjectClass(object),"finish","()V"));
            stopped = true;

        }catch (const runtime_error &e){
            const char *err = e.what();
            return -1;
        }
        pSoundTouch->clear();

        delete inFile;
        inFile = nullptr;
        delete this;

        return 0;
    }

    void stop(){
        stopped = true;
    }

    bool cantContinue(){
        return stopped||this!=current;
    }

    int getAudioLength(){
        if(inFile != nullptr)
            return inFile->getLengthMS()/1000;
        else
            return 0;
    }

    int getCurrent(){
        if(inFile != nullptr)
            return round((float)inFile->getElapsedMS() /1000);
        else
            return 0;
    }

    void seekTo(int seconds){
        if(inFile != nullptr)
            inFile->seekTo(seconds);
    }

    bool isPlaying() {
        return !stopped;
    }

private:
    void passResultBuffer(JNIEnv* env,jobject object,SAMPLETYPE buffer[],int size){
        env->SetFloatArrayRegion(sampleData, 0, size,buffer);
        env->CallVoidMethod(object,method,stopped,sampleData,size);
    }
};

static void _setErrmsg(const char *msg)
{
	_errMsg = msg;
}

#ifdef _OPENMP

#include <pthread.h>
extern pthread_key_t gomp_tls_key;
static void * _p_gomp_tls = NULL;

static int _init_threading(bool warn)
{
	void *ptr = pthread_getspecific(gomp_tls_key);
	if (ptr == NULL)
	{
		pthread_setspecific(gomp_tls_key, _p_gomp_tls);
	}
	else
	{
		_p_gomp_tls = ptr;
	}
	// Where critical, show warning if storage still not properly initialized
	if ((warn) && (_p_gomp_tls == NULL))
	{
		_setErrmsg("Error - OpenMP threading not properly initialized: Call SoundTouch.getVersionString() from the App main thread!");
		return -1;
	}
	return 0;
}

#else
static int _init_threading(bool warn)
{
	return 0;
}
#endif


extern "C" DLL_PUBLIC jlong Java_dev_zzksoft_soundtouch_SoundTouch_newInstance(JNIEnv *env,jclass thiz)
{
	return (jlong)(new SoundTouch());
}

extern "C" DLL_PUBLIC void Java_dev_zzksoft_soundtouch_SoundTouch_deleteInstance(JNIEnv *env, jobject thiz, jlong handle)
{
	SoundTouch *ptr = (SoundTouch*)handle;
	delete ptr;
}


extern "C" DLL_PUBLIC void Java_dev_zzksoft_soundtouch_SoundTouch_setTempo(JNIEnv *env, jobject thiz, jlong handle, jfloat tempo)
{
	SoundTouch *ptr = (SoundTouch*)handle;
	ptr->setTempo(tempo);
}


extern "C" DLL_PUBLIC void Java_dev_zzksoft_soundtouch_SoundTouch_setPitchSemiTones(JNIEnv *env, jobject thiz, jlong handle, jfloat pitch)
{
	SoundTouch *ptr = (SoundTouch*)handle;
	ptr->setPitchSemiTones(pitch);
}


extern "C" DLL_PUBLIC void Java_dev_zzksoft_soundtouch_SoundTouch_setSpeed(JNIEnv *env, jobject thiz, jlong handle, jfloat speed)
{
	SoundTouch *ptr = (SoundTouch*)handle;
	ptr->setRate(speed);
}


extern "C" DLL_PUBLIC jstring Java_dev_zzksoft_soundtouch_SoundTouch_getErrorString(JNIEnv *env,
																					jclass thiz)
{
	jstring result = env->NewStringUTF(_errMsg.c_str());
	_errMsg.clear();

	return result;
}

extern "C" DLL_PUBLIC jint Java_dev_zzksoft_soundtouch_SoundTouch_playMusic(JNIEnv *env, jobject thiz, jlong handle, jstring jinputFile)
{
    if(current!=nullptr){
        current->stop();
        current = nullptr;
    }
    current = new MusicTask();
    auto *pSoundTouch = (SoundTouch*)handle;
    const char *inputFile = env->GetStringUTFChars(jinputFile, 0);
    int result = current->play(pSoundTouch,inputFile,env,thiz);
    env->ReleaseStringUTFChars(jinputFile, inputFile);
    return result;
}

extern "C"
JNIEXPORT jint JNICALL
Java_dev_zzksoft_soundtouch_SoundTouch_getAudioLength(JNIEnv *env, jobject thiz) {
    if(current != nullptr)
        return current->getAudioLength();
    else
        return 0;
}

extern "C"
JNIEXPORT jint JNICALL
Java_dev_zzksoft_soundtouch_SoundTouch_getCurrent(JNIEnv *env, jobject thiz) {
	if(current!= nullptr)
		return current->getCurrent();
	else
		return 0;
}

extern "C"
JNIEXPORT void JNICALL
Java_dev_zzksoft_soundtouch_SoundTouch_seekTo(JNIEnv *env, jobject thiz, jint seconds) {
    if(current != nullptr)
        current->seekTo(seconds);
}

extern "C"
JNIEXPORT void JNICALL
Java_dev_zzksoft_soundtouch_SoundTouch_stop(JNIEnv *env, jobject thiz) {
    if(current != nullptr)
        current->stop();
}


extern "C"
JNIEXPORT jboolean JNICALL
Java_dev_zzksoft_soundtouch_SoundTouch_isPlaying(JNIEnv *env, jobject thiz) {
    if(current != nullptr)
        return current->isPlaying();
    return false;
}
