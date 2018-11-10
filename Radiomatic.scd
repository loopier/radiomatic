(
~boot = {
~numplayers = 3;
~players;
~mixerbusses = ();
~syncbus = Bus.control(s, 1);
~currentstate = Array.fill(~numplayers, {Dictionary.new});

~samplespath = "/Users/roger/Dropbox/++PROJECTS/LOOPIER/code/SAMPLEMATIC/samples/";
~logpath = PathName(thisProcess.nowExecutingPath).parentPath++"logs/";


// utils
~loadbufs = {
	arg path;
	var bufs = ();
	PathName(path).entries.do{
		arg file, i;
		bufs.put( i, Buffer.read(s, file.fullPath); );
	};
	bufs
};

~makebusses = {
	arg numbusses;
	var busses = ();
	numbusses.do {
		arg i;
		busses.put(i, Bus.audio(s, 1));
	};
	busses
};

// Execute this when you like the sound of it, to store it in the log's folder
~savecomposition = {
	var file, filename, compositionstring;
	filename = ~logpath++"radiomatic."++Date.getDate.asSortableString++".txt";
	File.use(filename, "w", { arg f;
		~currentstate.do({ arg dic, i;
			f.write(([i]++dic.asArray).asString);
			f.write("\n");
		})
	});
};


// boot sequence
// prepare control and audio busses
~mixerbusses = ~makebusses.value(~numplayers);
s.options.numOutputBusChannels = s.options.numOutputBusChannels
+ ~mixerbusses[~mixerbusses.size-1].index  // last  mixer bus index
+ 1; // extra one for ~sync bus

s.waitForBoot({
	// Clock
	SynthDef(\sync, { arg dur=4; Out.kr(~syncbus, Impulse.kr(1/dur)); }).add;
	// Samples (buffer) player
	SynthDef(\bpbufrd, {
		arg buf, rate=1.0, start=0.0, dur=1.0, t_reset=0, phase=0.0, amp=1, out=0, syncbus=2;
		var sig, pos, end, resetpos, sync;
		sync = In.kr(syncbus);
		dur = BufDur.kr(buf) * dur;
		rate = BufRateScale.kr(buf) * rate;
		end = BufFrames.kr(buf);
		resetpos = BufFrames.kr(buf) * start;
		// phase = BufFrames.kr(buf) * phase;
		pos = Phasor.ar(
			trig: Impulse.kr(1/dur, phase) + t_reset + sync,
			rate: rate,
			start: 0,
			end: end,
			resetPos:resetpos
		);
		sig = BufRd.ar(2, buf, pos, 0);
		sig = Mix.ar(sig) * amp;
		Out.ar(out, Mix.ar(sig));
	}).add;
	// Audio mixer
	SynthDef(\mixer, {
		arg in0, in1, in2, in3,
		amp0=1, amp1=1, amp2=1, amp3=1,
		amp = 0.3,
		out=0;
		var ins, amps;
		ins = In.ar([in0, in1, in2, in3]);
		amps = [amp0, amp1, amp2, amp3];
		Out.ar(out, Splay.ar(ins * amps * amp, 0.25));
	}).add;
	// load samples to buffers
	~bufs = ~loadbufs.value(~samplespath);

	s.sync;
	// setup clock
	~mixer = Synth(\mixer);
	s.sync;
	// setup players
	~players = Array.fill(~numplayers, {
		arg i;
		var defaultbuf, outbus;
		defaultbuf = ~bufs[0];
		outbus = ~mixerbusses[i];
		Synth(\bpbufrd, [
			buf: defaultbuf,
			out: outbus,
			syncbus: ~syncbus;
		]);
	});

	~players.size.postln;
	// patch players outputs to mixer inputs
	~numplayers.do { arg i; ~mixer.set(\in++(i.asSymbol), ~mixerbusses[i]); };

	s.plotTree;
	s.meter;
});

// Functions to control samples
~playplayer = {arg player, value=1; ~playeramp.value(player, value); player.postln};
~stopplayer = {arg player; ~playplayer.value(player, 0);};
~resetplayer = {arg player; ~players[player].set(\t_reset, 1); player.postln};
~playerbuf = {arg player, buf; ~players[player].set(\buf, buf);};
~playerdur = {arg player, value;
	if (value > 0.99) {value = 1} {value};
	~players[player].set(\dur, value);
	// ~players[player].get(\dur, {arg v; v.postln});
};
~playerrate = {arg player, value; ~players[player].set(\rate, value); };
~playerphase = {arg player, value; ~players[player].set(\phase, value);};
~playerstartpos= {arg player, value; ~players[player].set(\start, value);};
~playeramp = {arg player, value; ~mixer.set(\amp++player.asSymbol, value)};

~mastervolume = {arg value; ~mixer.set(\amp, value);};
~loopdur = {arg value;
	~sync.set(\dur, value);
	~players.size.do{ arg i;
		~playerdur.value(i);
		~resetplayer.value(i); };
};
~syncAll = {~players.size.do{ arg player; ~resetplayer.value(player) };};
};

~play = {
Tdef(\t, {
	inf.do {
		var seconds, numchanges;
		seconds = (Array.geom(6, 1, 2).choose); // seconds until next change
		~players.do {
			arg player, i;
			var buf, dur, start, phase, rate, amp, change;
			change = ((i+2)/(~players.size*2)).coin;
			if (change) {
				buf = ~bufs.choose;
				dur = rrand(0.1,1);
				start = rrand(0.1,1);
				phase = rrand(0.1,1);
				rate = rrand(0.1,1.0) * [-1,1].choose;
				amp = rrand(0.0,1.0);
				~playerbuf.value(i, buf);
				~playerdur.value(i, dur);
				~playerstartpos.value(i, start);
				~playerphase.value(i, phase);
				~playerrate.value(i, rate);
				~playeramp.value(i, amp);
				// [i, change, PathName(buf.path).fileNameWithoutExtension, dur.asStringPrec(2), start.asStringPrec(2), phase.asStringPrec(2), rate.asStringPrec(2), amp.asStringPrec(2)].postln;
				~currentstate[i].put(\buf, PathName(buf.path).fileNameWithoutExtension);
				~currentstate[i].put(\dur, rate.asStringPrec(2));
				~currentstate[i].put(\dur, dur.asStringPrec(2));
				~currentstate[i].put(\start ,start.asStringPrec(2));
				~currentstate[i].put(\phase, phase.asStringPrec(2));
				~currentstate[i].put(\amp, amp.asStringPrec(2));
				// ~currentstate.postln;
			} {
				[i, change].postln;
			};
		};
		seconds.postln;
		seconds.wait;
	};
}).play;
}
)
// Execute this when you like the sound of it, to store it in the log's folder
~boot.value;
~play.value;
~savecomposition.value;
