# Hark

Hark is an iPhone app that listens for important outdoor sounds and alerts
deaf and hard-of-hearing people with text, color, and vibration. It is built
for people who run, bike, or walk near traffic they cannot hear.

It is an aid, not a replacement for awareness of your surroundings.

## Sounds

- Urgent: siren, car horn, train horn, tire screech, gunshot
- Caution: someone shouting, truck backing up, motorcycle, thunder, dog
  growling, rattlesnake
- Info: bike bell, dog barking, skateboard

## How it works

- Microphone audio is streamed with `AVAudioEngine`.
- Apple's built-in `SoundAnalysis` classifier (version 1) labels the audio.
- Only the sounds above are reported, at 50% confidence or higher.
- Everything runs on the phone. Audio is never saved or sent.

## Requirements

- Xcode 26 or later
- iPhone running iOS 16 or later (use a real device; the simulator does not
  represent the microphone or vibration well)

## Running

1. Open `Hark.xcodeproj` in Xcode.
2. Select your iPhone as the run destination and set your signing team.
3. Build and run, then tap Start.

## Credits

Built with Apple's SwiftUI, AVFoundation, and SoundAnalysis frameworks.
Entry for the Congressional App Challenge.
