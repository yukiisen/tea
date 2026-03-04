const std = @import("std");

const Sound = @import("sekai").Sound;
const Texture2D = @import("sekai").Texture2D;
const z = @import("zmath");

pub const GeneralInfo = struct {
    /// silence in ms before playing audio.
    AudioLeadIn: u32 = 0,
    /// time in ms to start audio preview
    PreviewTime: u32 = 0,
    /// wtf is this??
    Countdown: CountDown = .NoCountdown,
    /// wtf is this??
    SampleSet: SampleSet = .Normal,
    /// whether we should display a warning about flashy colors
    EpilepsyWarning: bool = false,
    /// something for mania.
    SpecialStyle: bool  = false,
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
    Title: []const u8 = &.{},
    /// Romanised song artist 
    Artist: []const u8 = &.{},
    /// Beatmap creator
    Creator: []const u8 = &.{},
    /// Difficulty name
    Version: []const u8 = &.{},
    /// Original media the song was produced for
    Source: []const u8 = &.{},
    Tags: []const u8 = &.{},
    /// Difficulty ID
    BeatmapID: u32 = 0, 
    /// Beatmap ID
    BeatmapSetID: u32 = 0, 
};

pub const Difficulty = struct {
    /// HP setting (0–10)
    HPDrainRate: f32 = 0, 
    /// CS setting (0–10)
    keyCount: u8 = 4, 
    /// Base slider velocity in hundreds of osu!pixels per beat
    sliderMultiplier: f32 = 1.4, 
    /// Amount of slider ticks per beat
    sliderTickRate: f32 = 1, 
};

/// TODO: support video events
pub const Event = union(enum) {
    Background: Background,
    Break: Break,
};

pub const Background = struct {
    filename: []const u8,
    /// will be filled only when used.
    background: ?Texture2D = null,
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
    normalSet: SampleSet,
    additionSet: SampleSet,
    index: u32,
    volume: u32,
    filename: []const u8,
};

pub const HitObject = struct {
    /// we keep the x value here in order to allow players to change keycound on converted maps
    x: u32,
    /// Time when the object is to be hit, in milliseconds from the beginning of the beatmap's audio.
    time: u32, 
    /// for hold notes
    endTime: u32,
    /// the type of the object
    type: HitObjectType, 
    /// Bit flags indicating the hitsound applied to the object.
    hitSound: u8,
    hitSample: HitSample,
};

pub const HitObjectType = enum { Hold, Normal };

pub const Beatmap = struct {
    // this contains the entire .osu file content, don't use pls
    buffer: []const u8,
    audio: Sound,
    general: GeneralInfo,
    metadata: Metadata,
    difficulty: Difficulty,
    events: std.ArrayList(Event),
    timingPoints: std.ArrayList(TimingPoint),
    colors: std.ArrayList(z.Vec), 
    hitObjects: std.ArrayList(HitObject),



    const empty: Beatmap = .{
        .events = .empty,
        .timingPoints = .empty,
        .colors = .empty,
        .hitObjects = .empty,
        .difficulty = .{},
        .general = undefined,
        .metadata = .{},
        .buffer = &.{},
        .audio = undefined,
    };

    pub fn deinit(self: *Beatmap, allocator: std.mem.Allocator) void {
        self.colors.deinit(allocator);
        self.hitObjects.deinit(allocator);
        self.events.deinit(allocator);
        self.timingPoints.deinit(allocator);
        allocator.free(self.buffer);
    }
};


const Section = enum {
    None,
    General,
    Metadata,
    Difficulty,
    Events,
    Editor,
    TimingPoints,
    Colours,
    HitObjects,
};

fn parseSection(line: []const u8) Section {
    return switch (line[1]) {
        'G' => .General,
        'M' => .Metadata,
        'D' => .Difficulty,
        'E' => if (line[2] == 'v') .Events else .Editor,
        'T' => .TimingPoints,
        'H' => .HitObjects,
        'C' => .Colours,
        else => unreachable,
    };
}

fn parseEvent(line: []const u8) ?Event {
    var params = std.mem.splitScalar(u8, line, ',');

    const eventType = params.next() orelse return null;
    const startTime = params.next() orelse return null;

    switch (eventType[0]) {
        '0' => {
            const filename = params.next() orelse return null;
            const offset: z.Vec = .{ 
                std.fmt.parseFloat(f32, params.next() orelse "0") catch return null,
                std.fmt.parseFloat(f32, params.next() orelse "0") catch return null, 
                0, 0 
            };
            return .{ .Background = .{ .filename = filename[1..filename.len - 1], .offset = offset } };
        },
        '1', 'V' => return null, 
        '2', 'B' => return .{ 
            .Break = .{
                .startTime = std.fmt.parseInt(u32, startTime, 10) catch return null, 
                .endTime = std.fmt.parseInt(u32, startTime, 10) catch return null 
            }
        }, 
        else => return null,
    }
}

fn parseTimingPoint(line: []const u8) !TimingPoint {
    var params = std.mem.splitScalar(u8, line, ',');
    var tp: TimingPoint = undefined;
    
    const time = params.next() orelse return error.FuckWeCannotParse;
    const beatLength = params.next() orelse return error.FuckWeCannotParse;
    const meter = params.next() orelse return error.FuckWeCannotParse;
    const sampleSet = params.next() orelse return error.FuckWeCannotParse;
    const sampleIndex = params.next() orelse return error.FuckWeCannotParse;
    const volume = params.next() orelse return error.FuckWeCannotParse;
    const uninherited = params.next() orelse return error.FuckWeCannotParse;
    const effects = params.next() orelse return error.FuckWeCannotParse;

    tp.time = try std.fmt.parseInt(u32, time, 10);
    tp.beatLength = try std.fmt.parseFloat(f32, beatLength);
    tp.meter = try std.fmt.parseInt(u32, meter, 10);
    tp.sampleSet = @enumFromInt(try std.fmt.parseInt(u32, sampleSet, 10));
    tp.sampleIndex = try std.fmt.parseInt(u32, sampleIndex, 10);
    tp.volume = try std.fmt.parseInt(u32, volume, 10);
    tp.uninherited = uninherited[0] == '1';
    tp.effects = try std.fmt.parseInt(u8, effects, 10);

    return tp;
}

fn parseHitObject(line: []const u8) !HitObject {
    var params = std.mem.splitScalar(u8, line, ',');
    
    const x = params.next() orelse return error.FuckWeCouldntParse;
    _ = params.next() orelse return error.FuckWeCouldntParse; // we drop y.
    const time = params.next() orelse return error.FuckWeCouldntParse;
    const objT = params.next() orelse return error.FuckWeCouldntParse;
    const objType = try std.fmt.parseInt(u8, objT, 10);
    const hitsound = params.next() orelse return error.FuckWeCouldntParse;

    var obj: HitObject = undefined;
    obj.endTime = 0;
    
    obj.x = try std.fmt.parseInt(u32, x, 10);
    obj.time = try std.fmt.parseInt(u32, time, 10);
    obj.type = if (objType & 1 << 0 == 0) .Hold else .Normal;
    obj.hitSound = try std.fmt.parseInt(u8, hitsound, 10);

    var hitSample = std.mem.splitScalar(u8, params.next() orelse return error.FuckWeMessedUp, ':');

    if (obj.type == .Hold) obj.endTime = try std.fmt.parseInt(u32, hitSample.next() orelse return error.Fuck, 10);

    const normalSet = hitSample.next() orelse return error.FuckWeMessedUp;
    const additionSet = hitSample.next() orelse return error.FuckWeMessedUp;
    const index = hitSample.next() orelse return error.FuckWeMessedUp;
    const volume = hitSample.next() orelse return error.FuckWeMessedUp;
    const filename = hitSample.next() orelse return error.FuckWeMessedUp;

    obj.hitSample.normalSet = @enumFromInt(try std.fmt.parseInt(u32, normalSet, 10));
    obj.hitSample.additionSet = @enumFromInt(try std.fmt.parseInt(u32, additionSet, 10));
    obj.hitSample.index = try std.fmt.parseInt(u32, index, 10);
    obj.hitSample.volume = try std.fmt.parseInt(u32, volume, 10);
    obj.hitSample.filename = filename;

    return obj;
}


fn parseColor(line: []const u8) z.Vec {
    const idx = std.mem.indexOfScalar(u8, line, ':') orelse 0;

    const val = std.mem.trim(u8, line[idx + 1..], " ");
    var comps = std.mem.splitScalar(u8, val, ',');

    var vec: z.Vec = undefined;

    vec[0] = std.fmt.parseFloat(f32, comps.next().?) catch 0;
    vec[1] = std.fmt.parseFloat(f32, comps.next().?) catch 0;
    vec[2] = std.fmt.parseFloat(f32, comps.next().?) catch 0;
    vec[3] = std.fmt.parseFloat(f32, comps.next().?) catch 0;

    return vec;
}

fn parseSectionVars(comptime S: type, s: *S, line: []const u8) void {
    const idx = std.mem.indexOfScalar(u8, line, ':') orelse return;

    const key = std.mem.trim(u8, line[0..idx], " ");
    const val = std.mem.trim(u8, line[idx + 1..], " ");

    const info = @typeInfo(S).@"struct"; // asserted because why not.

    inline for (info.fields) |f| {
        if (std.mem.eql(u8, f.name, key)) {
            switch (@typeInfo(f.type)) {
                inline .int => @field(s, f.name) = std.fmt.parseInt(f.type, val, 10) catch 0,
                inline .float => @field(s, f.name) = std.fmt.parseFloat(f.type, val) catch 0,
                inline .bool => @field(s, f.name) = (std.fmt.parseUnsigned(u1, val, 2) catch 0) == 1,
                inline .@"enum" => @field(s, f.name) = @enumFromInt(std.fmt.parseUnsigned(u8, val, 10) catch 0),
                inline .@"pointer" => @field(s, f.name) = val,
                else => unreachable,
            }
        }
    }
}

pub fn loadBeatmapFromFile(io: std.Io, allocator: std.mem.Allocator, filename: []const u8) !Beatmap {
    const file = try std.Io.Dir.cwd().openFile(io, filename, .{ .mode = .read_only });
    defer file.close(io);

    const stat = try file.stat(io);
    const size = stat.size;

    // I wonder if this is the right way to read a file.
    const buffer = try allocator.alloc(u8, size);

    _ = try file.readPositionalAll(io, buffer, 0);

    var lines = std.mem.splitScalar(u8, buffer[3..], '\n');
    var bmp: Beatmap = .empty;
    errdefer bmp.deinit(allocator);

    bmp.buffer = buffer;
    if (!std.mem.eql(u8, lines.next() orelse &.{}, "osu file format v128")) return error.FuckBMPFileBroken;

    var section: Section = .None;

    while (lines.next()) |line| {
        if (line.len == 0) continue;

        if (line[0] == '[') {
            section = parseSection(line);
            continue;
        }

        switch (section) {
            .Events => if (parseEvent(line)) |event| { try bmp.events.append(allocator, event); },
            .TimingPoints => try bmp.timingPoints.append(allocator, try parseTimingPoint(line)),
            .HitObjects => try bmp.hitObjects.append(allocator, try parseHitObject(line)),
            .Colours => try bmp.colors.append(allocator, parseColor(line)),
            .Difficulty => parseSectionVars(Difficulty, &bmp.difficulty, line),
            .Metadata => parseSectionVars(Metadata, &bmp.metadata, line),
            .General => parseSectionVars(GeneralInfo, &bmp.general, line),
            else => {}
        }
    }

    return bmp;
}
