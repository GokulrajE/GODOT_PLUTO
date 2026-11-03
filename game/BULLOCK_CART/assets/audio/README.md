# Bullock Trail audio

Downloaded/generated 27 October 2026. All playback files are bundled; Python and network access are not runtime dependencies.

## Active music

`bgm1.mp3` and `bgm2.mp3` were supplied by the user on 27 October 2026. The original MP3s are used without transcoding: stereo, 48 kHz, approximately 4:26 and 6:03 respectively. Source/license metadata was not supplied.

BGM1 starts on entering Bullock Trail and continues into the first race. Race again advances to the other track; natural track completion also advances and wraps the two-song playlist. Tracks do not overlap. Music mute pauses playback so unmute resumes the same song position. Race pause, volume controls and speech ducking apply to both songs. The old tabla track is retained but no longer played.

## Credits and editing

- `tabla-loop.ogg`: **Electronic Indian tabla tune**, obscure music, [source](https://opengameart.org/content/electronic-indian-tabla-tune), [CC0](https://creativecommons.org/publicdomain/zero/1.0/). A 15–47 second excerpt, one-second wrap crossfade, loudness target −18 LUFS / −2 dB true peak, Ogg Vorbis at 44.1 kHz. Result: 31 seconds. This is Indian electronic percussion, not a Tamil-language song.
- `crowd-bed.ogg`: **Free Crowd Cheering Sounds**, Gregor Quendel, [source](https://opengameart.org/content/free-crowd-cheering-sounds), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Track 10, first 14 seconds, one-second wrap crossfade, normalized, 13-second Ogg loop.
- `crowd-cheer.ogg`: same creator/collection/license, track 04, first four seconds, 0.1-second fade in and one-second fade out, normalized, Ogg. These recordings are generic crowd ambience and cheering, not Tamil speech.

## Tamil encouragement

Original text synthesized using `edge-tts` with the named Microsoft Edge voices. These are synthetic voices, not recordings of specific people. No voice cloning. Rate +15% for Valluvar and +12% for Pallavi. Native MP3 output is retained.

| File | Voice | Phrase | Meaning |
| --- | --- | --- | --- |
| tamil-collect.mp3 | ta-IN-ValluvarNeural | அருமை! அப்படியே போங்க! | Great! Keep going! |
| tamil-streak.mp3 | ta-IN-PallaviNeural | சூப்பர்! தொடர்ந்து முன்னேறுங்க! | Super! Keep moving forward! |
| tamil-overtake.mp3 | ta-IN-ValluvarNeural | முந்திட்டீங்க! கலக்குங்க! | You overtook them! Keep it up! |
| tamil-finish.mp3 | ta-IN-PallaviNeural | வாழ்த்துக்கள்! அருமையாக முடிச்சிட்டீங்க! | Congratulations! You finished wonderfully! |

Authoring example (not required to run the game):

```powershell
$env:PYTHONPATH = Join-Path (Get-Location).Path '.godot/tools/audio-python'
python -m edge_tts --voice ta-IN-ValluvarNeural --rate '+15%' --text 'அருமை! அப்படியே போங்க!' --write-media game/BULLOCK_CART/assets/audio/tamil-collect.mp3
```

Runtime voice lines have a five-second cooldown; finishing a race can override it. The music drops by 7 dB during speech. Pause freezes all five players. Crowd volume also controls Tamil speech; zero prevents new speech and stops the current line. BGM, crowd and effects levels are independent.
