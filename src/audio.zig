const std = @import("std");

const ma = @import("deps/miniaudio.zig");

/// High-Level Abstraction over Miniaudio.
/// Used to load/play Sound objects.
/// TODO: implement sound groups.
pub const Audio = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    /// main audio player.
    engine: *ma.ma_engine,
    /// used to wait for loading
    fence: *ma.ma_fence,
    /// map of sound objects/labels
    /// this could probably be implemented in another way..
    sounds: std.StringHashMap(Sound),

    pub fn init(allocator: std.mem.Allocator) !Self {
        // miniaudio stores pointers of its structs so we allocate them to keep the same location.
        const engine = try allocator.create(ma.ma_engine);
        const fence = try allocator.create(ma.ma_fence);

        if (ma.ma_engine_init(null, engine) != ma.MA_SUCCESS) return error.FuckMiniaudioMessedUpEngineInit;
        if (ma.ma_fence_init(fence) != ma.MA_SUCCESS) return error.FuckMiniaudioMessedUpFenceinit;

        return .{ 
            .allocator = allocator,
            .engine = engine,
            .sounds = .init(allocator),
            .fence = fence,
        };
    }

    pub fn deinit(self: *Self) void {
        ma.ma_fence_uninit(self.fence);
        ma.ma_engine_uninit(self.engine);
        var iter = self.sounds.valueIterator();
        while (iter.next()) |sound| {
            sound.*.deinit();
        }
        self.*.sounds.deinit();
        self.allocator.destroy(self.engine);
        self.allocator.destroy(self.fence);
    }

    /// Default volume is 1.
    pub fn setVolume(self: Self, volume: f32) void {
        _ = ma.ma_engine_set_volume(self.engine, volume);
    }

    /// Default volume is 1.
    pub fn getVolume(self: Self) f32 {
        return ma.ma_engine_get_volume(self.engine);
    }

    pub fn createSound(self: *Self, label: []const u8, config: SoundConfig) !Sound {
        // Toggle sound init flags based on config
        var flags: i32 = 0; 
        if (!config.pitch) flags |= ma.MA_SOUND_FLAG_NO_PITCH;
        if (config.async) flags |= ma.MA_SOUND_FLAG_ASYNC;
        if (config.decode) flags |= ma.MA_SOUND_FLAG_DECODE;
        if (!config.spatialization) flags |= ma.MA_SOUND_FLAG_NO_SPATIALIZATION;
        if (config.stream) flags |= ma.MA_SOUND_FLAG_STREAM;

        const sound = try Sound.init(self.allocator, config.path, self, flags);
        try self.*.sounds.put(label, sound);

        return sound;
    }

    /// blocks the thread and waits until all sound objects (loaded with this interface) are loaded/decoded into memory.
    pub fn waitLoading(self: Self) void {
        _ = ma.ma_fence_wait(self.fence);
    }
};

/// Used to configure Sounds by the Audio service.
pub const SoundConfig = struct {
    /// setting this to false will optimize output but you can't change the pitch in return
    pitch: bool = true,
    /// whether to pre-decode the file or not
    decode: bool = true,
    /// load the sound file asyncronously
    async: bool = false,
    /// steam the file instead of reading it into memory
    stream: bool = false,
    /// something about positioning the audio in 3D space.
    /// shall be improved later.
    spatialization: bool = false,
    /// file to load
    path: []const u8,
};

/// Loads and Configures audio for playback
/// This doesn't host any data and can be safely copied.
/// A sound object holds per-track configuration to make applying filters easier.
pub const Sound = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    sound: *ma.ma_sound,
    allow_pitch: bool,

    pub fn init(allocator: std.mem.Allocator, path: []const u8, audio: *Audio, flags: i32) !Self {
        const sound = try allocator.create(ma.ma_sound);
        if (ma.ma_sound_init_from_file(audio.engine, path.ptr, 0, null, audio.fence, sound) != ma.MA_SUCCESS) return error.FuckSoundInitMessedUp;

        return .{
            .allocator = allocator,
            .sound = sound,
            .allow_pitch = flags & ma.MA_SOUND_FLAG_NO_PITCH != 0,
        };
    }

    pub inline fn toggle(self: *Self) void {
        if (ma.ma_sound_is_playing(self.sound) == ma.MA_TRUE) self.pause() else self.play();
    }

    pub inline fn stop(self: *Self) void {
        self.pause();
        self.seek(0);
    }

    pub inline fn play(self: *Self) void {
        _ = ma.ma_sound_start(self.sound);
    }

    pub inline fn pause(self: *Self) void {
        _ = ma.ma_sound_stop(self.sound);
    }

    /// moves the playback cursor to `time` (in seconds)
    pub inline fn seek(self: Self, time: f32) void {
        _ = ma.ma_sound_seek_to_second(self.sound, time);
    }

    /// Default volume is 1.
    pub inline fn setVolume(self: Self, volume: f32) void {
        _ = ma.ma_sound_set_volume(self.sound, volume);
    }

    /// Default volume is 1.
    pub inline fn getVolume(self: Self) f32 {
        return ma.ma_sound_get_volume(&self.sound);
    }

    /// changes the pitch of a sound
    /// this function won't work if you created the sound with { pitch = false }
    pub inline fn setPitch(self: Self, pitch: f32) void {
        if (!self.allow_pitch) return;
        ma.ma_sound_set_pitch(self.sound, pitch);
    }

    /// enables/diables looping in this sound.
    pub inline fn setLoop(self: Self, v: bool) void {
        ma.ma_sound_set_looping(self.sound, @intFromBool(v));
    }

    pub fn deinit(self: Self) void {
        ma.ma_sound_uninit(self.sound);
        self.allocator.destroy(self.sound);
    }
};
