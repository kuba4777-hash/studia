(
s.waitForBoot({
    s.freeAll; OSCdef.freeAll; s.sync;

    SynthDef(\WitcherPhonkEngine, {
        | intensity=0, danger=0, combat=0, dialogue=0, ai_combat=0, ai_dark=0 |

        var sig, kick, snare, hats, cowbell, bass808, pad, bassTrig;
        var l_int, l_danger, l_combat, l_dialogue, l_ai_comb, l_ai_dark;
        var tempo, clock, barClock, drumEnv, ducking, cowbellScale, drive;

        // --- WYGŁADZANIE ---
        l_int = Lag.kr(intensity, 0.2);
        l_danger = Lag.kr(danger, 1.0);
        l_combat = Lag.kr(combat, 0.5);
        l_dialogue = Lag.kr(dialogue, 1.3);
        l_ai_comb = Lag.kr(ai_combat, 2.0);
        l_ai_dark = Lag.kr(ai_dark, 3.0);

        // --- RYTMIKA ---
        tempo = (105 + (l_combat * 15)) / 60;
        clock = Impulse.kr(tempo * 4); // Szesnastki

        // Rytm basu: 1000 0000 1010 0000 (Phonkowa synkopa)
        bassTrig = Demand.kr(clock, 0, Dseq([1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0], inf));

        // --- PERKUSJA ---
        // Kick - mocny, ale bez przesadnego "pierdzenia"
        drumEnv = EnvGen.kr(Env.perc(0.005, 0.25), PulseDivider.kr(clock, 4));
        kick = SinOsc.ar(EnvGen.kr(Env([60, 35], [0.08], \exp), PulseDivider.kr(clock, 4))) * drumEnv;
        kick = (kick * 2).distort * 0.6;

        hats = HPF.ar(WhiteNoise.ar, 7000) * EnvGen.kr(Env.perc(0.001, 0.04), clock) * 0.15;

        // Sidechain (Ducking) - klucz do czystego miksu
        ducking = 1.0 - EnvGen.kr(Env.perc(0.01, 0.3), PulseDivider.kr(clock, 4), levelScale: 0.8);

        // --- BASS 808 (Rzadszy rytm) ---
        drive = (l_combat + l_int).clip(0, 1);
        bass808 = LFSaw.ar(33.midicps, 0, 0.5) + SinOsc.ar(33.midicps);
        bass808 = LPF.ar(bass808, 150 + (drive * 800));
        // Envelope tylko na bassTrig (nie na każdy kick!)
        bass808 = bass808 * EnvGen.kr(Env.perc(0.05, 1.2), bassTrig);
        bass808 = (bass808 * (1.5 + (drive * 2))).softclip * 0.4;
        bass808 = bass808 * ducking;

        // --- COWBELL ---
        cowbellScale = Demand.kr(PulseDivider.kr(clock, 4), 0, Dseq([72, 75, 77, 72, 80, 77].midicps, inf));
        cowbell = Pulse.ar(cowbellScale, 0.4) * EnvGen.kr(Env.perc(0.001, 0.3), PulseDivider.kr(clock, 2));
        cowbell = BPF.ar(cowbell, cowbellScale, 0.2) * 0.3 * (l_combat + 0.2).clip(0, 1);
        cowbell = HPF.ar(cowbell, 400); // Wycinamy dół z cowbella

        // --- ATMOSFERA (Witcher Improv) ---
        pad = Saw.ar([45.midicps, 52.midicps, 55.midicps]) * 0.04;
        pad = LPF.ar(pad, 300 + (l_ai_dark * 1000));
        pad = FreeVerb.ar(pad, 0.5, 0.8);

        // --- MIX ---
        sig = kick + bass808 + hats + cowbell + pad;

        // Dialog - mocniejszy Lowpass (efekt "za ścianą")
        sig = LPF.ar(sig, 20000 - (l_dialogue * 19000));

        // Master - Limiter zamiast sztywnego mnożnika
        sig = Limiter.ar(sig, 0.95);

        Out.ar(0, sig ! 2);
    }).add;

    s.sync;
    ~engine = Synth(\WitcherPhonkEngine);

    OSCdef(\receiver, { |msg|
        if(~engine.notNil, {
            ~engine.set(
                \intensity, msg[1],
                \danger, msg[2],
                \combat, msg[3],
                \dialogue, msg[4],
                \ai_combat, msg[5],
                \ai_dark, msg[6]
            );
        });
    }, "/engine/state");

    "=== WITCHER PHONK 2.1 CLEAN URUCHOMIONY ===".postln;
});
)