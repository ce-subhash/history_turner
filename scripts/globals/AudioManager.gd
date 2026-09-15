## AudioManager.gd
## Autoload Singleton managing sound effects (SFX) and background music (BGM).
## Synthesizes crisp 16-bit PCM AudioStreamWav audio dynamically in memory.
extends Node

# Audio players
var bgm_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
const SFX_CHANNEL_COUNT: int = 8
var current_sfx_channel: int = 0

# Cached AudioStreamWAV sounds
var snd_lane_left: AudioStreamWAV
var snd_lane_right: AudioStreamWAV
var snd_jump: AudioStreamWAV
var snd_slide: AudioStreamWAV
var snd_fist: AudioStreamWAV
var snd_crown: AudioStreamWAV
var snd_gate: AudioStreamWAV
var snd_crash: AudioStreamWAV
var snd_void_fall: AudioStreamWAV
var snd_ability: AudioStreamWAV
var snd_bgm_loop: AudioStreamWAV

var bgm_enabled: bool = true
var sfx_enabled: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_channels()
	_synthesize_all_audio()
	_start_bgm()


func _setup_audio_channels() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGMPlayer"
	bgm_player.volume_db = -18.0
	add_child(bgm_player)

	for i in range(SFX_CHANNEL_COUNT):
		var p = AudioStreamPlayer.new()
		p.name = "SFXChannel_%d" % i
		p.volume_db = -3.0
		add_child(p)
		sfx_players.append(p)


## Synthesizes 16-bit PCM audio waveforms for all game audio events.
func _synthesize_all_audio() -> void:
	snd_lane_left = _create_whoosh_sound(true)
	snd_lane_right = _create_whoosh_sound(false)
	snd_jump = _create_jump_sound()
	snd_slide = _create_slide_sound()
	snd_fist = _create_chime_sound([523.25, 659.25, 783.99], 0.28) # C5, E5, G5
	snd_crown = _create_chime_sound([659.25, 830.61, 987.77, 1318.51], 0.38) # E5, G#5, B5, E6
	snd_gate = _create_gate_sound()
	snd_crash = _create_crash_sound()
	snd_void_fall = _create_void_fall_sound()
	snd_ability = _create_ability_sound()
	snd_bgm_loop = _create_music_loop()


# --- Sound Effect Triggers ---

func play_sfx_lane_switch(direction: int) -> void:
	if not sfx_enabled:
		return
	_play_sound(snd_lane_left if direction < 0 else snd_lane_right)


func play_sfx_jump() -> void:
	if not sfx_enabled:
		return
	_play_sound(snd_jump)


func play_sfx_slide() -> void:
	if not sfx_enabled:
		return
	_play_sound(snd_slide)


func play_sfx_collect_fist() -> void:
	if not sfx_enabled:
		return
	_play_sound(snd_fist)


func play_sfx_collect_crown() -> void:
	if not sfx_enabled:
		return
	_play_sound(snd_crown)


func play_sfx_gate() -> void:
	if not sfx_enabled:
		return
	_play_sound(snd_gate)


func play_sfx_crash() -> void:
	if not sfx_enabled:
		return
	_play_sound(snd_crash)


func play_sfx_void_fall() -> void:
	if not sfx_enabled:
		return
	_play_sound(snd_void_fall)


func play_sfx_ability() -> void:
	if not sfx_enabled:
		return
	_play_sound(snd_ability)


func _play_sound(stream: AudioStreamWAV) -> void:
	if not stream or sfx_players.is_empty():
		return
	var player = sfx_players[current_sfx_channel]
	current_sfx_channel = (current_sfx_channel + 1) % SFX_CHANNEL_COUNT
	player.stream = stream
	player.play()


func _start_bgm() -> void:
	if not bgm_enabled or not snd_bgm_loop:
		return
	bgm_player.stream = snd_bgm_loop
	bgm_player.play()


func _process(_delta: float) -> void:
	# Keep ambient BGM looping seamlessly
	if bgm_enabled and bgm_player and not bgm_player.playing:
		bgm_player.play()


# ==============================================================================
# --- Procedural 16-Bit PCM Synthesis Engine ---
# ==============================================================================

## Helper: Converts float array [-1.0, 1.0] into 16-bit signed PCM byte buffer.
func _pcm_bytes_from_floats(samples: Array[float]) -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var val = clampi(int(samples[i] * 32767.0), -32767, 32767)
		if val < 0:
			val += 65536
		bytes[i * 2] = val & 0xFF
		bytes[i * 2 + 1] = (val >> 8) & 0xFF
	return bytes


func _create_stream(samples: Array[float], sample_rate: int = 44100, is_loop: bool = false) -> AudioStreamWAV:
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = _pcm_bytes_from_floats(samples)
	if is_loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = samples.size()
	return wav


## Whoosh for lane switching
func _create_whoosh_sound(_is_left: bool) -> AudioStreamWAV:
	var sr = 44100
	var dur = 0.16
	var count = int(sr * dur)
	var samples: Array[float] = []
	samples.resize(count)

	for i in range(count):
		var t = float(i) / float(sr)
		var progress = t / dur
		var env = sin(progress * PI)
		# Filtered noise + low tone
		var noise = (randf() * 2.0 - 1.0) * 0.4
		var sweep = sin(2.0 * PI * (320.0 - progress * 140.0) * t) * 0.6
		samples[i] = (noise + sweep) * env * 0.85

	return _create_stream(samples, sr)


## Jump upward whoosh
func _create_jump_sound() -> AudioStreamWAV:
	var sr = 44100
	var dur = 0.22
	var count = int(sr * dur)
	var samples: Array[float] = []
	samples.resize(count)

	for i in range(count):
		var t = float(i) / float(sr)
		var progress = t / dur
		var env = pow(1.0 - progress, 1.2) * (1.0 - exp(-t * 80.0))
		var freq = lerpf(240.0, 720.0, progress * progress)
		var tone = sin(2.0 * PI * freq * t) * 0.75
		var noise = (randf() * 2.0 - 1.0) * 0.25 * env
		samples[i] = (tone + noise) * env * 0.9

	return _create_stream(samples, sr)


## Slide gravel friction scuff
func _create_slide_sound() -> AudioStreamWAV:
	var sr = 44100
	var dur = 0.40
	var count = int(sr * dur)
	var samples: Array[float] = []
	samples.resize(count)

	for i in range(count):
		var t = float(i) / float(sr)
		var progress = t / dur
		var env = sin(progress * PI)
		var noise = (randf() * 2.0 - 1.0) * 0.65
		var rumble = sin(2.0 * PI * 95.0 * t) * 0.35
		samples[i] = (noise + rumble) * env * 0.75

	return _create_stream(samples, sr)


## Musical chord chime for collectibles
func _create_chime_sound(chord_freqs: Array, dur: float) -> AudioStreamWAV:
	var sr = 44100
	var count = int(sr * dur)
	var samples: Array[float] = []
	samples.resize(count)

	for i in range(count):
		var t = float(i) / float(sr)
		var progress = t / dur
		var env = exp(-progress * 6.5) * (1.0 - exp(-t * 200.0))
		var sample_sum = 0.0
		for f in chord_freqs:
			sample_sum += sin(2.0 * PI * f * t)
			# Harmonic overtone
			sample_sum += sin(2.0 * PI * f * 2.0 * t) * 0.3
		samples[i] = (sample_sum / float(chord_freqs.size())) * env * 0.85

	return _create_stream(samples, sr)


## Epic Decision Gate warp chord
func _create_gate_sound() -> AudioStreamWAV:
	var sr = 44100
	var dur = 0.65
	var count = int(sr * dur)
	var samples: Array[float] = []
	samples.resize(count)
	var freqs = [220.0, 277.18, 329.63, 440.0, 554.37] # A major triad

	for i in range(count):
		var t = float(i) / float(sr)
		var progress = t / dur
		var env = sin(progress * PI) * exp(-progress * 2.5)
		var s = 0.0
		for f in freqs:
			var chorus_detune = sin(t * 8.0) * 2.5
			s += sin(2.0 * PI * (f + chorus_detune) * t)
		samples[i] = (s / float(freqs.size())) * env * 0.9

	return _create_stream(samples, sr)


## Heavy impact crash
func _create_crash_sound() -> AudioStreamWAV:
	var sr = 44100
	var dur = 0.5
	var count = int(sr * dur)
	var samples: Array[float] = []
	samples.resize(count)

	for i in range(count):
		var t = float(i) / float(sr)
		var progress = t / dur
		var env = exp(-progress * 7.0)
		var thud_freq = lerpf(120.0, 35.0, progress)
		var thud = sin(2.0 * PI * thud_freq * t) * 0.65
		var burst = (randf() * 2.0 - 1.0) * exp(-progress * 15.0) * 0.7
		samples[i] = (thud + burst) * env * 0.95

	return _create_stream(samples, sr)


## Descending fall into the void whistle
func _create_void_fall_sound() -> AudioStreamWAV:
	var sr = 44100
	var dur = 1.3
	var count = int(sr * dur)
	var samples: Array[float] = []
	samples.resize(count)

	for i in range(count):
		var t = float(i) / float(sr)
		var progress = t / dur
		var env = sin(progress * PI)
		var freq = lerpf(820.0, 95.0, pow(progress, 1.4))
		var whistle = sin(2.0 * PI * freq * t) * 0.75
		var wind = (randf() * 2.0 - 1.0) * 0.35 * progress
		samples[i] = (whistle + wind) * env * 0.9

	return _create_stream(samples, sr)


## Active ability energy surge
func _create_ability_sound() -> AudioStreamWAV:
	var sr = 44100
	var dur = 0.7
	var count = int(sr * dur)
	var samples: Array[float] = []
	samples.resize(count)

	for i in range(count):
		var t = float(i) / float(sr)
		var progress = t / dur
		var env = sin(progress * PI)
		var freq = lerpf(220.0, 880.0, progress)
		var shimmer = sin(2.0 * PI * freq * t) * sin(2.0 * PI * (freq * 1.5) * t)
		samples[i] = shimmer * env * 0.85

	return _create_stream(samples, sr)


## Soothing, atmospheric ambient soundtrack (soft modal ancient chord progression without percussive beats)
func _create_music_loop() -> AudioStreamWAV:
	var sr = 22050
	var dur = 6.0 # 6-second seamless atmospheric loop
	var count = int(sr * dur)
	var samples: Array[float] = []
	samples.resize(count)

	# Ancient Roman Dorian chords: D minor9 (D3, F3, A3, C4, E4) to G major6 (G3, B3, D4, E4)
	var chord_d = [146.83, 174.61, 220.0, 261.63, 329.63]
	var chord_g = [196.00, 246.94, 293.66, 329.63, 392.00]

	for i in range(count):
		var t = float(i) / float(sr)
		var progress = t / dur
		# Smooth continuous loop swell
		var swell = sin(progress * PI) * 0.5 + 0.5

		# Crossfade between two ancient chords every 3 seconds
		var is_first_half = (progress < 0.5)
		var cur_chord = chord_d if is_first_half else chord_g
		var sub_t = fmod(t, 3.0) / 3.0
		var chord_env = sin(sub_t * PI)

		var pad = 0.0
		for idx in range(cur_chord.size()):
			var f = cur_chord[idx]
			var chorus = sin(t * 1.5 + float(idx)) * 0.4
			pad += sin(2.0 * PI * (f + chorus) * t) * (1.0 / float(cur_chord.size()))

		# Gentle warm sub-octave foundation (no kick/snare percussion)
		var sub_bass = sin(2.0 * PI * 73.42 * t) * 0.2

		samples[i] = clampf((pad * chord_env * 0.65 + sub_bass * 0.15) * swell * 0.55, -0.85, 0.85)

	return _create_stream(samples, sr, true)
