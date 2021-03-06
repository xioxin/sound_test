// License: BSD 3 Clause
// Copyright (C) 2010, Google Inc. All rights reserved.
// Copyright (C) 2015+, The LabSound Authors. All rights reserved.

#ifndef AudioDestinationMac_h
#define AudioDestinationMac_h

#include "LabSound/core/AudioBus.h"
#include "internal/AudioDestination.h"
#include <AudioUnit/AudioUnit.h>

namespace lab
{

// An AudioDestination using CoreAudio's default output AudioUnit

class AudioDestinationMac : public AudioDestination
{
public:
    AudioDestinationMac(AudioIOCallback &, size_t channelCount, float sampleRate, size_t renderQuantum = 128);
    virtual ~AudioDestinationMac();

    virtual void start() override;
    virtual void stop() override;

    float sampleRate() const override { return m_sampleRate; }

private:
    void configure();

    // DefaultOutputUnit callback
    static OSStatus inputProc(void * userData, AudioUnitRenderActionFlags *, const AudioTimeStamp *, UInt32 busNumber, UInt32 numberOfFrames, AudioBufferList * ioData);

    OSStatus render(UInt32 numberOfFrames, AudioBufferList * ioData);

    AudioUnit m_outputUnit;
    AudioIOCallback & m_callback;
    AudioBus m_renderBus;

    float m_sampleRate;
    size_t m_renderQuantum;

    class Input;  // LabSound
    Input * m_input;  // LabSound
};

}  // namespace lab

#endif  // AudioDestinationMac_h
