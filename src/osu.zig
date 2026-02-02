const std = @import("std");

const Sound = @import("sekai").Sound;
const Texture2D = @import("sekai").Texture2D;
const z = @import("zmath");

pub const GeneralInfo = struct {
    /// silence in ms before playing audio.
    audioLeadIn: u32 = 0,
    /// time in ms to start audio preview
    previewTime: u32 = 0,
    /// wtf is this??
    countdown: CountDown = .NoCountdown,
    /// wtf is this??
    sampleSet: SampleSet = .Normal,
    /// wtf is this??
    stackLatency: f32 = 0.7,
    /// whether we should display a warning about flashy colors
    epilepsyWarning: bool = false,
    /// something for mania.
    specialStyle: bool  = false,
};

pub const CountDown = enum (u8) {
    NoCountdown = 0,
    Normal = 1,
    Half = 2,
    Double = 3
};

pub const SampleSet = enum (u8) {
    /// for compatibility with timing points
    Default = 0,
    Normal = 1,
    Drum = 2,
    Soft = 3
};

pub const Metadata = struct {
    /// Romanised song title
    title: []const u8,
    /// Romanised song artist 
    artist: []const u8,
    /// Beatmap creator
    creator: []const u8,
    /// Difficulty name
    version: []const u8,
    /// Original media the song was produced for
    source: []const u8,
    tags: [][]const u8,
    /// Difficulty ID
    beatmapID: u32, 
    /// Beatmap ID
    beatmapSetID: u32, 
};

pub const Difficulty = struct {
    /// HP setting (0–10)
    HPDrainRate: f32, 
    /// CS setting (0–10)
    circleSize: f32, 
    /// OD setting (0–10)
    overallDifficulty: f32, 
    /// AR setting (0–10)
    approachRate: f32, 
    /// Base slider velocity in hundreds of osu!pixels per beat
    sliderMultiplier: f32, 
    /// Amount of slider ticks per beat
    sliderTickRate: f32, 
};

/// TODO: support video events
pub const Event = union(enum) {
    Background: Background,
    Break: Break,
};

pub const Background = struct {
    startTime: u32,
    background: Texture2D,
    offset: z.Vec,
};

pub const Break = struct {
    startTime: u32,
    endTime: u32,
};

pub const TimingPoint = struct {
    /// the start time for this point
    time: u32,
    /// This property has two meanings:
    /// - For uninherited timing points, the duration of a beat, in milliseconds.
    /// - For inherited timing points, a negative inverse slider velocity multiplier, as a percentage. For example, `-50` would make all sliders in this timing section twice as fast as `SliderMultiplier`.
    beatLength: f32, 
    /// Amount of beats in a measure. Inherited timing points ignore this property.
    meter: u32, 
    /// Default sample set for hit objects (0 = beatmap default, 1 = normal, 2 = soft, 3 = drum).
    sampleSet: SampleSet, 
    /// Custom sample index for hit objects. `0` indicates osu!'s default hitsounds.
    sampleIndex: u32, 
    /// Volume percentage for hit objects.
    volume: u32, 
    /// Whether or not the timing point is uninherited.
    uninherited: bool, 
    /// Bit flags that give the timing point extra effects.
    effects: u8, 
};

/// this entire shit is used to determine which hitsound file we should play.
/// if a filename was given, we don't really need any of this shift. (except volume)
pub const HitSample = struct {
    const Self = @This();

    normalSet: SampleSet,
    additionSet: SampleSet,
    index: u32,
    volume: f32,
    hitSound: ?Sound,

    // /// this should return a sound object based on the generated name of the samepleset
    // pub fn getSound (self: Self) Sound {
        
    // }
};

pub const HitObject = struct {
    /// Position in osu!pixels of the object.
    x: u32, y: u32, 
    /// Time when the object is to be hit, in milliseconds from the beginning of the beatmap's audio.
    time: u32, 
    /// Bit flags indicating the type of the object.
    type: u8, 
    /// Bit flags indicating the hitsound applied to the object.
    hitSound: u8, 
    hitSample: HitSample,
};

pub const Beatmap = struct {
    // this contains the entire .osu file content, don't use pls
    buffer: []const u8,
    audio: Sound,
    general: GeneralInfo,
    metadata: Metadata,
    difficulty: Difficulty,
    events: []const Event,
    timingPoints: []const TimingPoint,
    /// array of combo colors.
    colors: []const z.Vec, 
};


/// I don't know if we have this in std so we implement it :)
pub const BufferReader = struct {
    const Self = @This();

    cursor: usize = 0,
    buffer: []const u8,

    pub fn init(buffer: []const u8) Self {
        return .{ .buffer = buffer };
    }

    pub fn seek(self: *Self, pos: u32) void {
        self.*.cursor = pos;
    }

    pub fn readLine(self: *Self) ?[]const u8 {
        if (self.cursor >= self.buffer.len) return null;

        const start = self.cursor;
        while (self.cursor < self.buffer.len and self.buffer[self.cursor] != '\n') {
            self.cursor += 1;
        }

        const line = self.buffer[start..self.cursor];
        if (self.cursor < self.buffer.len) self.cursor += 1;

        return std.mem.trimRight(u8, line, "\r");
    }

    pub fn readUntil(self: *Self, c: u8) []const u8 {
        if (self.cursor >= self.buffer.len) return null;

        const start = self.cursor;
        while (self.cursor < self.buffer.len and self.buffer[self.cursor] != c) {
            self.cursor += 1;
        }

        const line = self.buffer[start..self.cursor];
        if (self.cursor < self.buffer.len) self.cursor += 1;

        return std.mem.trimRight(u8, line, "\r");
    }

    pub fn readNBytes(self: *Self, n: usize) []const u8 {
        const current = self.cursor;
        self.*.cursor += n;
        return self.buffer[current..self.cursor];
    }
};

const Section = enum {
    None,
    General,
    Metadata,
    Difficulty,
    Events,
    TimingPoints,
    HitObjects,
};

pub fn loadBeatMapFromFile(io: std.Io, allocator: std.mem.Allocator, filename: []const u8) !Beatmap {
    const file = try std.Io.Dir.cwd().openFile(io, filename, .{ .mode = .read_only });
    defer file.close(io);

    const stat = try file.stat(io);
    const size = stat.size;

    // I wonder if this is the right way to read a file.
    const buffer = try allocator.alloc(u8, size);
    defer allocator.free(buffer); // free mem on errors

    _ = try file.readPositionalAll(io, buffer, 0);

    var reader = BufferReader.init(buffer);
    var bmp: Beatmap = undefined;

    bmp.buffer = buffer;

    if (!std.mem.eql(u8, reader.readLine(), "osu file format v128")) return error.FuckSomethingBrokeInBMPLoading;

    // we collect metadata first
    while (!std.mem.eql(u8, reader.readLine(), "[General]")) {} // skip lines until general section
    
    var line: []const u8 = undefined;

    return bmp;
}
