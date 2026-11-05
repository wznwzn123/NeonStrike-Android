extends Node
class_name NeonAudio

var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var music_enabled := true
var sfx_enabled := true
var master_volume := 0.75
var effect_cache: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    music_player = AudioStreamPlayer.new()
    music_player.stream = _make_music()
    music_player.volume_db = linear_to_db(0.22)
    music_player.bus = "Master"
    add_child(music_player)
    sfx_player = AudioStreamPlayer.new()
    sfx_player.bus = "Master"
    add_child(sfx_player)
    for effect in ["fire", "hit", "reload", "hurt"]:
        effect_cache[effect] = _make_effect(effect)
    if music_enabled:
        music_player.play()

func _make_music() -> AudioStreamWAV:
    var rate := 22050
    var seconds := 8.0
    var count := int(rate * seconds)
    var data := PackedByteArray()
    data.resize(count * 2)
    var notes := [110.0, 146.83, 164.81, 130.81]
    for i in range(count):
        var t := float(i) / rate
        var note: float = notes[int(t / 2.0) % notes.size()]
        var fade := minf(1.0, t / 0.5) * minf(1.0, (seconds - t) / 0.5)
        var sample := sin(TAU * note * t) * 0.055 + sin(TAU * note * 2.0 * t) * 0.018
        sample *= fade * (0.72 + 0.28 * sin(TAU * 0.25 * t))
        data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = rate
    stream.stereo = false
    stream.data = data
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    stream.loop_begin = 0
    stream.loop_end = count
    return stream

func _make_effect(kind: String) -> AudioStreamWAV:
    var rate := 22050
    var seconds := 0.16
    if kind == "hit":
        seconds = 0.11
    elif kind == "reload":
        seconds = 0.32
    elif kind == "hurt":
        seconds = 0.20
    var count := int(rate * seconds)
    var data := PackedByteArray()
    data.resize(count * 2)
    var base := 95.0
    if kind == "fire":
        base = 82.0
    elif kind == "hit":
        base = 520.0
    elif kind == "reload":
        base = 240.0
    elif kind == "hurt":
        base = 150.0
    for i in range(count):
        var t := float(i) / rate
        var envelope := exp(-t * (13.0 if kind == "fire" else 20.0))
        var wave := sin(TAU * (base - t * base * 0.8) * t)
        if kind == "fire":
            wave = wave * 0.65 + sin(TAU * 38.0 * t) * 0.35
        elif kind == "hit":
            wave = wave * 0.55 + sin(TAU * 1100.0 * t) * 0.2
        elif kind == "reload":
            wave = sin(TAU * base * t) * 0.5 + sin(TAU * 730.0 * t) * 0.2
        elif kind == "hurt":
            wave = wave * 0.7 + sin(TAU * 65.0 * t) * 0.3
        data.encode_s16(i * 2, int(clampf(wave * envelope * 0.7, -1.0, 1.0) * 32767.0))
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = rate
    stream.stereo = false
    stream.data = data
    return stream

func play_effect(kind: String) -> void:
    if not sfx_enabled or not effect_cache.has(kind):
        return
    sfx_player.stream = effect_cache[kind]
    sfx_player.play()

func set_music_enabled(enabled: bool) -> void:
    music_enabled = enabled
    if music_player == null:
        return
    if enabled and not music_player.playing:
        music_player.play()
    elif not enabled:
        music_player.stop()

func set_sfx_enabled(enabled: bool) -> void:
    sfx_enabled = enabled

func set_master_volume(value: float) -> void:
    master_volume = clampf(value, 0.0, 1.0)
    AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.001)))
