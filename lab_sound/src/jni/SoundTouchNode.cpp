//
// Created by Administrator on 2020/8/29.
//

#include "SoundTouchNode.h"

#include "LabSound/core/AudioBus.h"
#include "LabSound/core/AudioNodeInput.h"
#include "LabSound/core/AudioNodeOutput.h"
#include "LabSound/core/AudioSetting.h"
#include "LabSound/core/Macros.h"
#include "LabSound/extended/AudioContextLock.h"

#include "internal/Assertions.h"
#include "internal/AudioUtilities.h"

#include <algorithm>
#include <internal/VectorMath.h>

#include "libnyquist/Decoders.h"

using namespace lab;

const double DefaultGrainDuration = 0.020;  // 20ms

// Arbitrary upper limit on playback rate.
// Higher than expected rates can be useful when playing back oversampled buffers
// to minimize linear interpolation aliasing.
const double MaxRate = 1024;

SoundTouchNode::SoundTouchNode(double maxTempo)
        : AudioScheduledSourceNode()
        , m_sourceBus(std::make_shared<AudioSetting>("sourceBus", "SBUS", AudioSetting::Type::Bus))
        , m_isLooping(std::make_shared<AudioSetting>("loop", "LOOP", AudioSetting::Type::Bool))
        , m_loopStart(std::make_shared<AudioSetting>("loopStart", "STRT", AudioSetting::Type::Float))
        , m_loopEnd(std::make_shared<AudioSetting>("loopEnd", "END ", AudioSetting::Type::Float))
        , m_grainDuration(DefaultGrainDuration)
{
    m_gain = std::make_shared<AudioParam>("gain", "GAIN", 1.0, 0.0, 1.0);
    m_playbackRate = std::make_shared<AudioParam>("playbackRate", "RATE", 1.0, 0.0, MaxRate);
    m_detune = std::make_shared<AudioParam>("detune", "DTUNE", 0.0, -1.e6f, 1.e6f);

    m_params.push_back(m_gain);
    m_params.push_back(m_playbackRate);
    m_params.push_back(m_detune);

    m_settings.push_back(m_sourceBus);
    m_settings.push_back(m_isLooping);
    m_settings.push_back(m_loopStart);
    m_settings.push_back(m_loopEnd);

    m_sourceBus->setValueChanged([this]() {
        this->m_channelSetupRequested = true;
    });

    // Default to mono. A call to setBus() will set the number of output channels to that of the bus.
    addOutput(std::unique_ptr<AudioNodeOutput>(new AudioNodeOutput(this, 1)));

    m_soundTouch = std::make_shared<soundtouch::SoundTouch>();

    bufferSize = ceil(ProcessingSizeInFrames*2*maxTempo);
    soundTouchBuffer = new float[bufferSize];

    initialize();
}

SoundTouchNode::~SoundTouchNode()
{
    delete soundTouchBuffer;
    uninitialize();
}

void SoundTouchNode::process(ContextRenderLock & r, size_t framesToProcess)
{
    AudioBus * outputBus = output(0)->bus(r);

    if (!getBus() || !isInitialized() || !r.context())
    {
        outputBus->zero();
        return;
    }

    if (m_channelSetupRequested)
    {
        // channel count is changing, so output silence for one quantum to allow the
        // context to re-evaluate connectivity before rendering
        outputBus->zero();
        output(0)->setNumberOfChannels(r, getBus()->numberOfChannels());
        m_virtualReadIndex = 0;
        m_channelSetupRequested = false;
        return;
    }

    // After calling setBuffer() with a buffer having a different number of channels, there can in rare cases be a slight delay
    // before the output bus is updated to the new number of channels because of use of tryLocks() in the context's updating system.
    // In this case, if the the buffer has just been changed and we're not quite ready yet, then just output silence.
    if (numberOfChannels(r) != getBus()->numberOfChannels())
    {
        outputBus->zero();
        return;
    }

    if (m_startRequested)
    {
        // Do sanity checking of grain parameters versus buffer size.
        double bufferDuration = duration();

        double grainOffset = std::max(0.0, m_requestGrainOffset);
        m_grainOffset = std::min(bufferDuration, grainOffset);
        m_grainOffset = grainOffset;

        // Handle default/unspecified duration.
        double maxDuration = bufferDuration - grainOffset;
        double grainDuration = m_requestGrainDuration;
        if (!grainDuration)
            grainDuration = maxDuration;

        grainDuration = std::max(0.0, grainDuration);
        grainDuration = std::min(maxDuration, grainDuration);
        m_grainDuration = grainDuration;

        m_isGrain = true;
        m_startTime = m_requestWhen;

        // We call timeToSampleFrame here since at playbackRate == 1 we don't want to go through linear interpolation
        // at a sub-sample position since it will degrade the quality.
        // When aligned to the sample-frame the playback will be identical to the PCM data stored in the buffer.
        // Since playbackRate == 1 is very common, it's worth considering quality.

        /// @TODO consistently pick double or size_t through this entire API chain.
        m_virtualReadIndex = static_cast<double>(
                AudioUtilities::timeToSampleFrame(m_grainOffset, static_cast<double>(getBus()->sampleRate())));
        m_startRequested = false;
    }

//    size_t realFrameToProcess = ceil(framesToProcess/m_soundTouch->getInputOutputSampleRatio());
    size_t realFrameToProcess = ProcessingSizeInFrames;
    size_t quantumFrameOffset;
    size_t bufferFramesToProcess;

    updateSchedulingInfo(r, realFrameToProcess, outputBus, quantumFrameOffset, bufferFramesToProcess);

    if (!bufferFramesToProcess)
    {
        outputBus->zero();
        return;
    }

    // Render by reading directly from the buffer.
    if (!renderFromBuffer(r, outputBus, quantumFrameOffset, bufferFramesToProcess))
    {
        outputBus->zero();
        return;
    }

    // Apply the gain (in-place) to the output bus.
//    float totalGain = gain()->value(r);
//    outputBus->copyWithGainFrom(*outputBus, &m_lastGain, totalGain);
//    outputBus->clearSilentFlag();

    mixChannel(outputBus,bufferFramesToProcess);
    soundTouchRender(outputBus);
//    outputBus->channel(1)->zero();

}


// Returns true if we're finished.
bool SoundTouchNode::renderSilenceAndFinishIfNotLooping(ContextRenderLock & r, AudioBus * bus, size_t index, size_t framesToProcess)
{
    if (!loop())
    {
        // If we're not looping, then stop playing when we get to the end.

        if (framesToProcess > 0)
        {
            // We're not looping and we've reached the end of the sample data, but we still need to provide more output,
            // so generate silence for the remaining.
            for (unsigned i = 0; i < numberOfChannels(r); ++i)
            {
                memset(bus->channel(i)->mutableData() + index, 0, sizeof(float) * framesToProcess);
            }
        }

        finish(r);
        return true;
    }
    return false;
}

bool SoundTouchNode::renderFromBuffer(ContextRenderLock & r, AudioBus * bus, size_t destinationFrameOffset, size_t numberOfFrames)
{
    if (!r.context())
        return false;

    auto srcBus = getBus();

    if (!bus || !srcBus)
        return false;

    size_t numChannels = numberOfChannels(r);
    size_t busNumberOfChannels = bus->numberOfChannels();

    bool channelCountGood = numChannels && numChannels == busNumberOfChannels;
    ASSERT(channelCountGood);
    if (!channelCountGood)
        return false;

    // Sanity check destinationFrameOffset, numberOfFrames.
    size_t destinationLength = bus->length();

    bool isLengthGood = destinationLength <= 4096 && numberOfFrames <= 4096;
    ASSERT(isLengthGood);
    if (!isLengthGood)
        return false;

//    bool isOffsetGood = destinationFrameOffset <= destinationLength && destinationFrameOffset + numberOfFrames <= destinationLength;
//    ASSERT(isOffsetGood);
//    if (!isOffsetGood)
//        return false;

    // Offset the pointers to the correct offset frame.
    size_t writeIndex = destinationFrameOffset;

    size_t bufferLength = srcBus->length();
    double bufferSampleRate = srcBus->sampleRate();

    // Avoid converting from time to sample-frames twice by computing
    // the grain end time first before computing the sample frame.
    size_t endFrame = m_isGrain ? AudioUtilities::timeToSampleFrame(m_grainOffset + m_grainDuration, bufferSampleRate) : bufferLength;

    // This is a HACK to allow for HRTF tail-time - avoids glitch at end.
    // FIXME: implement tailTime for each AudioNode for a more general solution to this problem.
    // https://bugs.webkit.org/show_bug.cgi?id=77224
    if (m_isGrain)
        endFrame += 512;

    // Do some sanity checking.
    if (endFrame > bufferLength)
        endFrame = bufferLength;

    if (m_virtualReadIndex >= endFrame)
        m_virtualReadIndex = 0;  // reset to start

    // If the .loop attribute is true, then values of m_loopStart == 0 && m_loopEnd == 0 implies
    // that we should use the entire buffer as the loop, otherwise use the loop values in m_loopStart and m_loopEnd.
    double virtualEndFrame = static_cast<double>(endFrame);
    double virtualDeltaFrames = virtualEndFrame;

    double loopS = loopStart();
    double loopE = loopEnd();

    if (loop() && (loopS || loopE) && loopS >= 0 && loopE > 0 && loopS < loopE)
    {
        // Convert from seconds to sample-frames.
        double loopStartFrame = loopS * srcBus->sampleRate();
        double loopEndFrame = loopE * srcBus->sampleRate();

        virtualEndFrame = std::min(loopEndFrame, virtualEndFrame);
        virtualDeltaFrames = virtualEndFrame - loopStartFrame;
    }

    double pitchRate = totalPitchRate(r);

    // Sanity check that our playback rate isn't larger than the loop size.
    if (fabs(pitchRate) >= virtualDeltaFrames)
        return false;

    // Get local copy.
    double virtualReadIndex = m_virtualReadIndex;

    // Render loop - reading from the source buffer to the destination using linear interpolation.
    int framesToProcess = static_cast<int>(numberOfFrames);

    // Optimize for the very common case of playing back with pitchRate == 1.
    // We can avoid the linear interpolation.
    if (pitchRate == 1 && virtualReadIndex == floor(virtualReadIndex) && virtualDeltaFrames == floor(virtualDeltaFrames) && virtualEndFrame == floor(virtualEndFrame))
    {
        int readIndex = static_cast<int>(virtualReadIndex);
        int deltaFrames = static_cast<int>(virtualDeltaFrames);
        endFrame = static_cast<int>(virtualEndFrame);

        while (framesToProcess > 0)
        {
            int framesToEnd = static_cast<int>(endFrame) - readIndex;
            int framesThisTime = std::min(framesToProcess, framesToEnd);
            framesThisTime = std::max(0, framesThisTime);

            for (unsigned i = 0; i < numChannels; ++i)
            {
                memcpy(bus->channel(i)->mutableData() + writeIndex, srcBus->channel(i)->data() + readIndex, sizeof(float) * framesThisTime);
            }

            writeIndex += framesThisTime;
            readIndex += framesThisTime;
            framesToProcess -= framesThisTime;

            // Wrap-around.
            if (readIndex >= endFrame)
            {
                readIndex -= deltaFrames;
                if (renderSilenceAndFinishIfNotLooping(r, bus, static_cast<unsigned int>(writeIndex), static_cast<size_t>(framesToProcess)))
                    break;
            }
        }
        virtualReadIndex = readIndex;
    }
    else
    {
        while (framesToProcess--)
        {
            unsigned readIndex = static_cast<unsigned>(virtualReadIndex);
            double interpolationFactor = virtualReadIndex - readIndex;

            // For linear interpolation we need the next sample-frame too.
            unsigned readIndex2 = readIndex + 1;

            if (readIndex2 >= bufferLength)
            {
                if (loop())
                {
                    // Make sure to wrap around at the end of the buffer.
                    readIndex2 = static_cast<unsigned>(virtualReadIndex + 1 - virtualDeltaFrames);
                }
                else
                    readIndex2 = readIndex;
            }

            // Final sanity check on buffer access.
            // FIXME: as an optimization, try to get rid of this inner-loop check and put assertions and guards before the loop.
            if (readIndex >= bufferLength || readIndex2 >= bufferLength)
                break;

            // Linear interpolation.
            for (unsigned i = 0; i < numChannels; ++i)
            {
                float * destination = bus->channel(i)->mutableData();
                const float * source = srcBus->channel(i)->data();

                double sample1 = source[readIndex];
                double sample2 = source[readIndex2];
                double sample = (1.0 - interpolationFactor) * sample1 + interpolationFactor * sample2;

                destination[writeIndex] = static_cast<float>(sample);
            }
            writeIndex++;

            virtualReadIndex += pitchRate;

            // Wrap-around, retaining sub-sample position since virtualReadIndex is floating-point.
            if (virtualReadIndex >= virtualEndFrame)
            {
                virtualReadIndex -= virtualDeltaFrames;
                if (renderSilenceAndFinishIfNotLooping(r, bus, writeIndex, static_cast<size_t>(framesToProcess)))
                    break;
            }
        }
    }

    bus->clearSilentFlag();

    m_virtualReadIndex = virtualReadIndex;

    return true;
}

void SoundTouchNode::reset(ContextRenderLock & r)
{
    m_virtualReadIndex = 0;
    m_lastGain = gain()->value(r);
    AudioScheduledSourceNode::reset(r);
}

bool SoundTouchNode::setBus(ContextRenderLock & r, std::shared_ptr<AudioBus> buffer)
{
    ASSERT(r.context());

    m_sourceBus->setBus(buffer.get());
    // Do any necesssary re-configuration to the buffer's number of channels.
    output(0)->setNumberOfChannels(r, buffer ? buffer->numberOfChannels() : 0);
    m_virtualReadIndex = 0;
    m_soundTouch->setSampleRate(buffer->sampleRate());
    m_soundTouch->setChannels(buffer->numberOfChannels());
    return true;
}

size_t SoundTouchNode::numberOfChannels(ContextRenderLock & r)
{
    return output(0)->numberOfChannels();
}

void SoundTouchNode::startGrain(double when, double grainOffset)
{
    // Duration of 0 has special value, meaning calculate based on the entire buffer's duration.
    startGrain(when, grainOffset, 0);
}

void SoundTouchNode::startGrain(double when, double grainOffset, double grainDuration)
{
    if (!getBus())
        return;

    m_requestWhen = when;
    m_requestGrainOffset = grainOffset;
    m_requestGrainDuration = grainDuration;

    m_playbackState = SCHEDULED_STATE;
    m_startRequested = true;
}

float SoundTouchNode::duration() const
{
    auto bus = getBus();
    if (!bus)
        return 0;

    return bus->length() / bus->sampleRate();
}

double SoundTouchNode::totalPitchRate(ContextRenderLock & r)
{
    double dopplerRate = 1.0;
    if (m_pannerNode)
        dopplerRate = m_pannerNode->dopplerRate(r);

    // Incorporate buffer's sample-rate versus AudioContext's sample-rate.
    // Normally it's not an issue because buffers are loaded at the AudioContext's sample-rate, but we can handle it in any case.
    double sampleRateFactor = 1.0;
    if (getBus())
        sampleRateFactor = getBus()->sampleRate() / r.context()->sampleRate();

    double basePitchRate = playbackRate()->value(r);

    double totalRate = dopplerRate * sampleRateFactor * basePitchRate;
    totalRate *= pow(2, detune()->value(r) / 1200);

    // Sanity check the total rate.  It's very important that the resampler not get any bad rate values.
    totalRate = std::max(0.0, totalRate);
    if (!totalRate)
        totalRate = 1;  // zero rate is considered illegal
    totalRate = std::min(MaxRate, totalRate);

    bool isTotalRateValid = !std::isnan(totalRate) && !std::isinf(totalRate);
    ASSERT(isTotalRateValid);
    if (!isTotalRateValid)
        totalRate = 1.0;

    return totalRate;
}

bool SoundTouchNode::propagatesSilence(ContextRenderLock & r) const
{
    return !isPlayingOrScheduled() || hasFinished() || !m_sourceBus;
}

void SoundTouchNode::setPannerNode(PannerNode * pannerNode)
{
    m_pannerNode = pannerNode;
}

void SoundTouchNode::clearPannerNode()
{
    m_pannerNode = 0;
}

bool SoundTouchNode::loop() const
{
    return m_isLooping->valueBool();
}
void SoundTouchNode::setLoop(bool loop)
{
    m_isLooping->setBool(loop);
}

double SoundTouchNode::loopStart() const
{
    return m_loopStart->valueFloat();  // seconds
}

double SoundTouchNode::loopEnd() const
{
    return m_loopEnd->valueFloat();  // seconds
}

void SoundTouchNode::setLoopStart(double loopStart)
{
    m_loopStart->setFloat(static_cast<float>(loopStart));  // seconds
}

void SoundTouchNode::setLoopEnd(double loopEnd)
{
    m_loopEnd->setFloat(static_cast<float>(loopEnd));  // seconds
}

void SoundTouchNode::setRate(double value) {
//    m_soundTouch->setRate(value);
    playbackRate()->setValue(value);
    m_soundTouch->setPitch(1.0/value);
}

void SoundTouchNode::setPitch(double value) {
    m_soundTouch->setPitchSemiTones(value);
}

void SoundTouchNode::setTempo(double value) {
    m_soundTouch->setTempo(value);
}

template <typename T>
void interleaveStereo(T const * c1, T const * c2, T * dst, size_t count)
{
    auto dst_end = dst + count*2;
    while (dst != dst_end)
    {
        dst[0] = *c1;
        dst[1] = *c2;
        c1++;
        c2++;
        dst += 2;
    }
}

void SoundTouchNode::mixChannel(AudioBus* outputBus,int samples) {
    if(outputBus->numberOfChannels()==2){
        interleaveStereo(outputBus->channel(0)->data(),outputBus->channel(1)->data(),soundTouchBuffer,samples);
    }else{
        memcpy(outputBus->channel(0)->mutableData(),soundTouchBuffer,samples*sizeof(float));
    }
    // 将音频提交给SoundTouch处理进程
    m_soundTouch->putSamples(soundTouchBuffer, samples);
}

void SoundTouchNode::soundTouchRender(AudioBus *outputBus) {
    uint nSamples = ProcessingSizeInFrames;
    int received = 0,got = 0;

    memset(soundTouchBuffer,0,bufferSize);
    do{
        got = m_soundTouch->receiveSamples((soundTouchBuffer+received), nSamples-received);
        received += got;
    } while (got != 0);

//    __android_log_print(ANDROID_LOG_ERROR,"ST","%s%d","Received:",received);

    if(outputBus->numberOfChannels() == 2){
        nqr::DeinterleaveStereo(outputBus->channel(0)->mutableData(),outputBus->channel(1)->mutableData(),soundTouchBuffer,received*2);
    }else{
        memcpy(outputBus->channel(0)->mutableData(),soundTouchBuffer,nSamples*sizeof(float));
    }
}