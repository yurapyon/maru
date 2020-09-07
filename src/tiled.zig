const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;

const json = @import("json");

// fn parseHexFormatColorRgb(str: []const u8) ![3]u8 {
//     const r = try std.fmt.parseInt(u8, str[0..2], 16);
//     const g = try std.fmt.parseInt(u8, str[2..4], 16);
//     const b = try std.fmt.parseInt(u8, str[4..6], 16);
//     return [_]u8{ r, g, b };
// }
//
// fn parseHexFormatColorRgba(str: []const u8) ![4]u8 {
//     const r = try std.fmt.parseInt(u8, str[0..2], 16);
//     const g = try std.fmt.parseInt(u8, str[2..4], 16);
//     const b = try std.fmt.parseInt(u8, str[4..6], 16);
//     const a = try std.fmt.parseInt(u8, str[6..8], 16);
//     return [_]u8{ r, g, b, a };
// }

// TODO probably change the inplementation and just do it the 'normal way'

pub const Data = union(enum) {
    gids: []u64,
    base64_data: []u8,
};

pub const Chunk = struct {
    data: Data,
    x: i64,
    y: i64,
    width: i64,
    height: i64,
};

pub const PropertyValue = union(enum) {
    string: []u8,
    integer: i64,
    float: f64,
    boolean: bool,
};

pub const Property = struct {
    name: []u8,
    @"type": []u8,
    value: PropertyValue,
};

pub const TileLayer = struct {
    chunks: ?[]Chunk = null,
    compression: ?[]u8 = null,
    data: Data,
    encoding: ?[]u8 = null,
    id: i64,
    name: []u8,
    offsetx: ?f64 = null,
    offsety: ?f64 = null,
    opacity: f64,
    properties: ?[]Property = null,
    startx: ?i64 = null,
    starty: ?i64 = null,
    tintcolor: ?[]u8 = null,
    @"type": []u8,
    visible: bool,
    x: i64,
    y: i64,
    width: ?i64 = null,
    height: ?i64 = null,
};

pub const Point = struct {
    x: f64,
    y: f64,
};

pub const Text = struct {
    bold: ?bool = null,
    color: ?[]u8 = null,
    fontfamily: ?[]u8 = null,
    halign: ?[]u8 = null,
    italic: ?bool = null,
    kerning: ?bool = null,
    pixelsize: ?i64 = null,
    strikeout: ?bool = null,
    text: []u8,
    underline: ?bool = null,
    valign: ?[]u8 = null,
    wrap: ?bool = null,
};

pub const Object = struct {
    ellipse: ?bool = null,
    height: f64,
    gid: ?i64 = null,
    id: i64,
    name: []u8,
    point: ?bool = null,
    polygon: ?[]Point = null,
    polyline: ?[]Point = null,
    properties: ?[]Property = null,
    rotation: f64,
    template: ?[]u8 = null,
    text: ?Text = null,
    @"type": []u8,
    visible: bool,
    width: f64,
    x: f64,
    y: f64,
};

pub const ObjectGroup = struct {
    draworder: []u8,
    id: i64,
    name: []u8,
    objects: []Object,
    offsetx: ?f64 = null,
    offsety: ?f64 = null,
    opacity: f64,
    properties: ?[]Property = null,
    startx: ?i64 = null,
    starty: ?i64 = null,
    tintcolor: ?[]u8 = null,
    @"type": []u8,
    visible: bool,
    x: i64,
    y: i64,
    width: ?i64 = null,
    height: ?i64 = null,
};

pub const ImageLayer = struct {
    id: i64,
    image: []u8,
    name: []u8,
    offsetx: ?f64 = null,
    offsety: ?f64 = null,
    opacity: f64,
    properties: ?[]Property = null,
    startx: ?i64 = null,
    starty: ?i64 = null,
    tintcolor: ?[]u8 = null,
    transparentcolor: ?[]u8 = null,
    @"type": []u8,
    visible: bool,
    x: i64,
    y: i64,
    width: ?i64 = null,
    height: ?i64 = null,
};

pub const Group = struct {
    id: i64,
    layers: []Layer,
    name: []u8,
    offsetx: f64,
    offsety: f64,
    opacity: f64,
    properties: ?[]Property,
    startx: i64,
    starty: i64,
    tintcolor: ?[]u8,
    @"type": []u8,
    visible: bool,
    x: i64,
    y: i64,
    width: i64,
    height: i64,
};

pub const Layer = union(enum) {
    TileLayer: TileLayer,
    ObjectGroup: ObjectGroup,
    ImageLayer: ImageLayer,
    Group: Group,
};

pub const Frame = struct {
    tileid: i64,
    duration: i64,
};

pub const Tile = struct {
    id: i64,
    image: []u8,
    imagewidth: i64,
    imageheight: i64,
    properties: ?[]Property = null,
    object_group: ?ObjectGroup = null,
    animation: ?[]Frame = null,
    tile_type: ?[]u8 = null,
    probability: ?f64 = null,
};

pub const Grid = struct {
    height: i64,
    orientation: ?[]u8 = null,
    width: i64,
};

pub const TileOffset = struct {
    x: i64,
    y: i64,
};

pub const Terrain = struct {
    name: []u8,
    properties: ?[]Property = null,
    tile: i64,
};

pub const Tileset = struct {
    backgroundcolor: ?[]u8 = null,
    columns: i64,
    firstgid: i64,
    grid: ?Grid = null,
    image: []u8,
    imagewidth: i64,
    imageheight: i64,
    margin: i64,
    name: []u8,
    objectalignment: ?[]u8 = null,
    properties: ?[]Property = null,
    source: ?[]u8 = null,
    spacing: i64,
    terrains: ?[]Terrain = null,
    tilecount: i64,
    tiledversion: ?[]u8 = null,
    tileheight: i64,
    tileoffset: ?TileOffset = null,
    tiles: ?[]Tile = null,
    tilewidth: i64,
    transparentcolor: ?[]u8 = null,
    @"type": ?[]u8 = null,
    version: ?f64 = null,
    // TODO
    // wangsets
};

pub const Map = struct {
    const Self = @This();

    backgroundcolor: ?[]u8 = null,
    compressionlevel: i64,
    height: i64,
    hexsidelength: ?i64 = null,
    infinite: bool,
    layers: []Layer,
    nextlayerid: i64,
    nextobjectid: i64,
    orientation: []u8,
    properties: ?[]Property = null,
    renderorder: ?[]u8 = null,
    staggeraxis: ?[]u8 = null,
    staggerindex: ?[]u8 = null,
    tiledversion: []u8,
    tileheight: i64,
    tilewidth: i64,
    tilesets: []Tileset,
    @"type": []u8,
    version: f64,
    width: i64,

    pub fn init(allocator: *Allocator, json_str: []const u8) !Self {
        @setEvalBranchQuota(7000);
        var stream = json.TokenStream.init(json_str);
        return json.parse(Map, &stream, .{ .allocator = allocator });
    }

    pub fn deinit(self: *Self, allocator: *Allocator) void {
        json.parseFree(Self, self.*, .{ .allocator = allocator });
    }
};

test "tiled" {
    var alloc = std.testing.allocator;

    // TODO read file differently
    var file = try std.fs.cwd().openFile("tests/debug.json", .{ .read = true });
    defer file.close();
    const sz = try file.getEndPos();
    var buf = try alloc.alloc(u8, sz);
    defer alloc.free(buf);
    const read = file.readAll(buf);

    std.log.warn("{}", .{buf});

    var m = try Map.init(alloc, buf);
    defer m.deinit(alloc);
}
