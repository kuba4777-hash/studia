(
s.waitForBoot({
    s.freeAll; OSCdef.freeAll; s.sync;

    SynthDef(\AggressiveEngine, {
        | interior=0, tension=0, intensity=0, occlusion=0, hazard=0, health=1, mood=0 |

        var sig, wiatr, bas, krysztaly, puls; // Zmieniono 'kryształy' na 'krysztaly'
        var l = Lag.kr([interior, tension, intensity, occlusion, hazard, health, mood], 0.5);

        // 1. WIATR (Znika w jaskini)
        wiatr = BPF.ar(WhiteNoise.ar(0.05), 800 + (l[6] * 2000), 0.1) * (1 - l[0]);

        // 2. BAS (Pojawia się w jaskini i przy napięciu)
        bas = SinOsc.ar([40, 41] + (l[1] * 5), 0, 0.3) * l[0] * (1 + l[1]);

        // 3. KRYSZTALY (Gama zmienia się z Mood)
        krysztaly = Mix.fill(3, {
            var f = Select.kr((l[6] * 3).round, [60, 63, 67, 72].midicps);
            SinOsc.ar(f * [1, 2].choose, 0, Decay2.kr(Dust.kr(0.5 + (l[2] * 2)), 0.01, 1)) * 0.1
        }) * l[5];

        // 4. PULS ZAGROZENIA (Hazard)
        puls = LPF.ar(Saw.ar(50), 200) * LFPulse.kr(1 + (l[4] * 10)) * l[4];

        sig = wiatr + bas + krysztaly + puls;
        sig = FreeVerb.ar(sig, 0.3 + (l[0] * 0.4), 0.8) * l[5];

        Out.ar(0, (sig * 1.5).tanh ! 2);
    }).add;

    s.sync;
    ~engine = Synth(\AggressiveEngine);

    OSCdef(\receiver, { |msg|
        // Cichy impuls potwierdzający odebranie danych z Pythona
        { EnvGen.ar(Env.perc(0.001, 0.01), doneAction: 2) * PinkNoise.ar(0.01) }.play;

        ~engine.set(
            \interior, msg[1], \tension, msg[2], \intensity, msg[3],
            \occlusion, msg[4], \hazard, msg[5], \health, msg[6], \mood, msg[7]
        );
    }, "/engine/state");

    "=== SILNIK URUCHOMIONY (ASCII FIX) ===".postln;
});
)