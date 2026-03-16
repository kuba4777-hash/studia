(
s.waitForBoot({
    s.freeAll; OSCdef.freeAll; s.sync;

    SynthDef(\AdaptiveEmoRap, {
        | darkness=0, intensity=0, danger=0, r_val=0, g_val=0, b_val=0, sky=0, water=0 |

        var sig, piano, bass808, hats, snare, heartbeat;
        var l_dark, l_act, l_danger, l_sky, l_water;
        var baseTempo, finalTempo, beat, bassBeat, hatBeat;
        var seqIndex, rootMidi, chordPitches, pianoEnv;

        // Wygładzanie 8 zmiennych
        l_dark = Lag.kr(darkness, 1.2);
        l_act = Lag.kr(intensity, 0.2);
        l_danger = Lag.kr(danger, 0.5);
        l_sky = Lag.kr(sky, 1.0);
        l_water = Lag.kr(water, 1.5); // Powolne "odpływanie" dźwięku pod wodą

        // --- DYNAMIKA TEMPA (WODA SPOWALNIA WSZYSTKO) ---
        baseTempo = 1.30 + (l_act * 0.5);
        // Pod wodą tempo spada o 70%
        finalTempo = baseTempo * (1 - (l_water * 0.7));

        beat = Impulse.kr(finalTempo);
        bassBeat = PulseDivider.kr(beat, 4);
        hatBeat = Impulse.kr(finalTempo * 2);

        // --- PIANINO ---
        seqIndex = Stepper.kr(beat, 0, 0, 3);
        rootMidi = Select.kr(seqIndex, [62, 60, 58, 58]);
        chordPitches = [rootMidi, rootMidi+3, rootMidi+7].midicps;

        pianoEnv = EnvGen.kr(Env.perc(0.01, 2.0 / finalTempo), beat); // Wybrzmienie zależy od tempa
        piano = Mix.fill(3, { |i|
            var wobble = LFNoise2.kr(3).range(1.0 - (l_danger * 0.05), 1.0 + (l_danger * 0.05));
            SinOsc.ar(chordPitches[i] * wobble) * pianoEnv * 0.1
        });

        // POD WODĄ: Muzyka staje się głucha (LowPass Filter)
        piano = LPF.ar(piano, (2000 + (l_sky * 3000)) * (1 - (l_water * 0.85)));

        // --- PERKUSJA (Znika lub cichnie pod wodą) ---
        bass808 = SinOsc.ar((rootMidi - 24).midicps) * EnvGen.kr(Env.perc(0.01, 2.0), bassBeat) * l_act * (1 - (l_water * 0.5));
        hats = HPF.ar(WhiteNoise.ar, 9000) * EnvGen.kr(Env.perc(0.005, 0.03), hatBeat) * 0.05 * l_act * (1 - l_water);
        snare = BPF.ar(PinkNoise.ar, 2200, 0.5) * EnvGen.kr(Env.perc(0.005, 0.1), PulseDivider.kr(beat, 2, 1)) * 0.1 * l_act * (1 - l_water);

        // --- HEARTBEAT ---
        heartbeat = SinOsc.ar(45) * EnvGen.kr(Env.perc(0.01, 0.2), Impulse.kr(finalTempo * (1 + l_danger))) * l_danger * 0.5;

        sig = piano + bass808 + hats + snare + heartbeat;

        // POD WODĄ: Większy pogłos (Reverb)
        sig = FreeVerb.ar(sig, 0.4 + (l_water * 0.5), 0.85 + (l_water * 0.1), 0.3);

        Out.ar(0, Compander.ar(sig, sig, 0.5, 1.0, 0.3) ! 2);
    }).add;

    s.sync;
    ~engine = Synth(\AdaptiveEmoRap);

    OSCdef(\receiver, { |msg|
        if(~engine.notNil, {
            ~engine.set(
                \darkness, msg[1], \intensity, msg[2], \danger, msg[3],
                \r_val, msg[4], \g_val, msg[5], \b_val, msg[6], \sky, msg[7], \water, msg[8]
            );
        });
    }, "/engine/state");

    "=== EMO RAP UNDERWATER V33 URUCHOMIONY ===".postln;
});
)