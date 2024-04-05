const std = @import("std");

pub fn lerp(x: f32, y: f32, t: f32) f32 {
    return x * (1 - t) + y * t;
}

pub fn lerp2(x: [2]f32, y: [2]f32, t: f32) [2]f32 {
    return [_]f32{lerp(x[0], y[0], t), lerp(x[1], y[1], t)};
}

pub fn lerp3(x: [3]f32, y: [3]f32, t: f32) [3]f32 {
    return [_]f32{lerp(x[0], y[0], t), lerp(x[1], y[1], t), lerp(x[2], y[2], t)};
}

test lerp {
    std.debug.print("\n", .{});
    try std.testing.expect(lerp(0, 100, 0.5) == 50);
    try std.testing.expectEqual(lerp2(.{0, 0}, .{10, 10}, 0.5), [_]f32{5, 5});
    try std.testing.expectEqual(lerp3(.{0, 0, 0}, .{10, 10, 10}, 0.5), [_]f32{5, 5, 5});
}

pub const ChunkNoise = struct {
    seed: u32,
    octaves: u8 = 8,
    lacunarity: f32 = 2.0,
    gain: f32 = 0.5,
};