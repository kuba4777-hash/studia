(
s.waitForBoot({
    s.freeAll; OSCdef.freeAll; s.sync;

    SynthDef(\AggressiveEngine, {
        | darkness=0, interior=0 |

        // WSZYSTKIE VAR MUSZĄ BYĆ TUTAJ!
        var sig, wiatr, bas, krysztaly;
        var l_dark, l_int, bas_vol;

        l_dark = Lag.kr(darkness, 0.5);
        l_int = Lag.kr(interior, 0.5);

        // 1. WIATR (Dzień)
        wiatr = BPF.ar(WhiteNoise.ar(0.05), 800 + ((1 - l_dark) * 2000), 0.1) * (1 - l_dark) * (1 - l_int);

        // 2. BAS (Noc lub Jaskinia)
        bas_vol = max(l_dark, l_int);
        bas = SinOsc.ar([40, 41], 0, 0.3) * bas_vol;

        // 3. KRYSZTAŁY
        krysztaly = Mix.fill(3, {
            var f = Select.kr(((1 - l_dark) * 3).round, [60, 63, 67, 72].midicps);
            SinOsc.ar(f * [1, 2].choose, 0, Decay2.kr(Dust.kr(0.8), 0.01, 1)) * 0.1
        });

        sig = wiatr + bas + krysztaly;
        sig = FreeVerb.ar(sig, 0.3 + (l_int * 0.4), 0.8);

        Out.ar(0, (sig * 1.5).tanh ! 2);
    }).add;

    s.sync;
    ~engine = Synth(\AggressiveEngine);

    OSCdef(\receiver, { |msg|
        if(~engine.notNil, {
            ~engine.set(\darkness, msg[1], \interior, msg[2]);
        });
        // To wypisze wskaźniki w konsoli SuperCollidera:
        ("SC Otrzymał -> Mrok: " + msg[1].round(0.01) + " Jaskinia: " + msg[2].round(0.01)).postln;
    }, "/engine/state");

    "=== SILNIK Energiczny GOTOWY ===".postln;
});
)