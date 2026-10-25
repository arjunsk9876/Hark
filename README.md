# Hark

Hark is an iPhone app that listens for important outdoor sounds and alerts
deaf and hard-of-hearing people with text, color, and vibration. It is built
for people who run, bike, or walk near traffic they cannot hear.

It is an aid, not a replacement for awareness of your surroundings.

## Sounds

Hark listens for 36 sounds in seven groups:

- Vehicles and traffic: siren, car horn, truck horn, train horn, railroad
  crossing bell, tire screech, car alarm, backup beeper, motorcycle, engine
  revving, truck or bus, car passing, bike bell, skateboard
- Alarms and warnings: fire or smoke alarm, burglar alarm, civil defense
  siren, whistle
- People: screaming, shouting, baby crying
- Sudden events: gunshot, explosion, fireworks, glass breaking, crash
- Animals: dog barking, dog growling
- Weather: thunder
- Machinery: jackhammer, chainsaw, power tool, lawn mower, leaf blower,
  construction, helicopter

Apple's built-in classifier has no label for railroad crossing bell, car
alarm, burglar alarm, jackhammer, leaf blower, or construction machinery, so
those six are not detected yet.

## How it works

- Microphone audio is streamed with `AVAudioEngine`.
- Apple's built-in `SoundAnalysis` classifier (version 1) labels the audio.
- Each detected sound gets a live urgency score from 0 to 1, built from six
  signals: base danger of the sound, loudness above background noise, how
  fast it is getting louder, how suddenly it started, how long it has
  lasted, and the classifier's confidence.
- Below 0.25 there is no alert. The score sets the screen color (blue below
  0.4, orange below 0.7, red from 0.7 up), how long the alert stays up
  (2 s to 5 s), and the vibration:
  - strength, soft at 0.25 and full at 1
  - sharpness, a dull thud at low scores and a sharp knock at high ones
  - pulses per buzz: one for blue, two for orange, three for red
  - repeats while the sound continues, every 8 s at low scores down to
    every 1.5 s at high ones
- Listening keeps running with the screen locked (background audio). With
  the phone locked, Core Haptics cannot play, so Hark falls back to the
  system vibration and carries urgency by pulse count alone.
- Listening pauses for phone calls and Siri and resumes afterwards, and
  restarts on its own when headphones connect or iOS resets audio.
- Moving sounds show "Getting closer" or "Moving away" when their loudness
  rises or falls faster than 1.5 dB per second over 4 seconds.
- All weights and cut-offs live in `UrgencySettings.swift` and are starting
  guesses to tune by testing.
- Everything runs on the phone. Audio is never saved or sent.

## Screens

- Listen: what is happening now, with icon, name, and color. One Start/Stop
  button, plus Recent and More links.
- Recent: the last 50 alerts with times, in memory only.
- More: Keep screen on, Debug (shows raw labels, the score, and each signal
  on the Listen screen), Model facts, and the safety note.
- Model facts: model, privacy, sounds, rules, and limits. A tested accuracy
  section appears once real results are added to `MeasuredAccuracy` in
  `ModelFactsView.swift`.
- First run: a short explanation and the safety note before the microphone
  prompt. If access is denied, the Listen screen offers to open Settings.

All text scales with Dynamic Type.

## Requirements

- Xcode 26 or later
- iPhone running iOS 16.6 or later (use a real device; the simulator does not
  represent the microphone or vibration well)

## Running

1. Open `Hark.xcodeproj` in Xcode.
2. Select your iPhone as the run destination and set your signing team.
3. Build and run, then tap Start.

## Credits

Built with Apple's SwiftUI, AVFoundation, and SoundAnalysis frameworks.
Entry for the Congressional App Challenge.
