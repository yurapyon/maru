const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn applyEffectToDefaultShader(
    allocator: *Allocator,
    comptime default_shader: []const u8,
    comptime default_effect: []const u8,
    maybe_effect: ?[]const u8,
) ![:0]u8 {
    const ins = std.mem.indexOfScalar(u8, default_shader, '@') orelse unreachable;
    const header = default_shader[0..ins];
    const footer = default_shader[(ins + 1)..];
    const effect = maybe_effect orelse default_effect;
    return std.mem.joinZ(allocator, "", &[_][]const u8{ header, effect, footer });
}
