const std = @import("std");
const gl = @import("zgl");
const Noise = @import("znoise").FnlGenerator;


const Vertex = struct { f32, f32, f32 };

const TriIndex = struct { u32, u32, u32 };

const Mesh = struct {
    vertices: []Vertex,
    indices: []TriIndex,
    vao: gl.VertexArray,
    vbo: gl.Buffer,
    ebo: gl.Buffer,

    pub fn free(self: @This(), allocator: std.mem.Allocator) void {
        allocator.free(self.vertices);
        allocator.free(self.indices);
        gl.deleteBuffer(self.vbo);
        gl.deleteBuffer(self.ebo);
        gl.deleteVertexArray(self.vao);

    }

    pub fn render(self: @This(), program: gl.Program) void {
        gl.useProgram(program);
        gl.bindVertexArray(self.vao);
        gl.drawElements(.triangles, self.indices.len * 3, .u32, 0);
        gl.bindVertexArray(.invalid);
    }
};

fn idx(x: usize, y: usize, max_y: usize) usize {
    return x + y * max_y;
}

pub const GridHeightMap = struct {
    heights: []f32,
    shape: [2]u32,
    dist: [2]f32,
    mesh: Mesh,
    allocator: std.mem.Allocator,

    pub fn free(self: GridHeightMap) void {
        self.mesh.free(self.allocator);
    }

    pub fn new(allocator: std.mem.Allocator, heights: []f32, shape: [2]u32, dist: [2]f32) !GridHeightMap {
        var ret = GridHeightMap{.allocator = allocator, .heights = heights, .shape = shape, .dist = dist, .mesh = undefined};
        try ret.createMesh();
        return ret;
    }

    pub fn render(self: GridHeightMap, program: gl.Program) void {
        self.mesh.render(program);
    }

    fn to_verts(self: GridHeightMap) ![]Vertex {
        const size: u32 = self.shape[0] * self.shape[1];
        const ret: []Vertex = try self.allocator.alloc(Vertex, size);
        for (0..self.shape[0]) |z| {
            for (0..self.shape[1]) |x| {
                ret[self.idx(.{@truncate(z), @truncate(x)})] = Vertex{@as(f32, @floatFromInt(x)) * self.dist[0], self.heights[self.idx(.{@truncate(z), @truncate(x)})], @as(f32, @floatFromInt(z)) * self.dist[1]};
            }
        }
        return ret;
    }

    pub fn idx(self: GridHeightMap, index: [2]u32) u32 {
        std.debug.assert(index[0] < self.shape[0]);
        std.debug.assert(index[1] < self.shape[1]);
        return index[0] * self.shape[1] + index[1];
    }

    pub fn get(self: GridHeightMap, index: [2]u32) f32 {
        return self.heights[self.idx(index)];
    }

    pub fn set(self: *GridHeightMap, index: [2]u32, value: f32) !void {
        self.heights[self.idx(index)] = value;
        //try self.updateMesh(self.idx(index), value);
    }

    //pub fn updateMesh(self: *HeightMap, index: u32, value: f32) !void {
    //}

    pub fn createMesh(self: *GridHeightMap) !void {
        const size = self.shape[0] * self.shape[1];

        var indices = try self.allocator.alloc(TriIndex, size * 8);
        errdefer self.allocator.free(indices);

        const check: [][4]bool = try self.allocator.alloc([4]bool, size);
        defer self.allocator.free(check);

        var indx: u32 = 0;
        for (0..self.shape[0]) |x| {
            for (0..self.shape[1]) |y| {
                const i: u32 = @truncate(x);
                const j: u32 = @truncate(y);
                const up = i -| 1 != 0;
                const down = i + 1 < self.shape[0];
                const left = j -| 1 != 0;
                const right = j + 1 < self.shape[1];
                //
                // {[-i, -j] [-i,  j] [-i, +j]}
                // {[ i, -j] [ i,  j] [ i, +j]}
                // {[+i, -j] [+i,  j] [+i, +j]}
                //
                if (!check[self.idx(.{i, j})][0] and up and left) { // 0
                    indices[indx] = TriIndex{self.idx(.{i, j}), self.idx(.{i, j - 1}), self.idx(.{i - 1, j - 1})};
                    indices[indx + 1] = TriIndex{self.idx(.{i, j}), self.idx(.{i - 1, j - 1}), self.idx(.{i - 1, j})};
                    check[self.idx(.{i, j})][0] = true;
                    check[self.idx(.{i, j - 1})][1] = true;
                    check[self.idx(.{i - 1, j})][2] = true;
                    check[self.idx(.{i - 1, j - 1})][3] = true;
                    indx += 2;
                }
                if (!check[self.idx(.{i, j})][1] and up and right) { // 1
                    indices[indx] = TriIndex{self.idx(.{i, j}), self.idx(.{i - 1, j}), self.idx(.{i - 1, j + 1})};
                    indices[indx + 1] = TriIndex{self.idx(.{i, j}), self.idx(.{i - 1, j + 1}), self.idx(.{i, j + 1})};
                    check[self.idx(.{i, j})][1] = true;
                    check[self.idx(.{i, j + 1})][0] = true;
                    check[self.idx(.{i - 1, j})][3] = true;
                    check[self.idx(.{i - 1, j + 1})][2] = true;
                    indx += 2;
                }
                if (!check[self.idx(.{i, j})][2] and down and left) { // 2
                    indices[indx] = TriIndex{self.idx(.{i, j}), self.idx(.{i + 1, j}), self.idx(.{i + 1, j - 1})};
                    indices[indx + 1] = TriIndex{self.idx(.{i, j}), self.idx(.{i + 1, j - 1}), self.idx(.{i, j - 1})};
                    check[self.idx(.{i, j})][2] = true;
                    check[self.idx(.{i, j - 1})][3] = true;
                    check[self.idx(.{i + 1, j})][0] = true;
                    check[self.idx(.{i + 1, j - 1})][1] = true;
                    indx += 2;
                }
                if (!check[self.idx(.{i, j})][3] and down and right) {  // 3
                    indices[indx] = TriIndex{self.idx(.{i, j}), self.idx(.{i, j + 1}), self.idx(.{i + 1, j + 1})};
                    indices[indx + 1] = TriIndex{self.idx(.{i, j}), self.idx(.{i + 1, j + 1}), self.idx(.{i + 1, j})};
                    check[self.idx(.{i, j})][3] = true;
                    check[self.idx(.{i, j + 1})][2] = true;
                    check[self.idx(.{i + 1, j})][1] = true;
                    check[self.idx(.{i + 1, j + 1})][0] = true;
                    indx += 2;
                }
            }
        }
        if (!self.allocator.resize(indices, indx)) {
            return error.FailedToResize;
        }
        indices.len = indx;

        const mesh = Mesh{
            .indices = indices,
            .vertices = try self.to_verts(),
            .ebo = gl.genBuffer(),
            .vao = gl.createVertexArray(),
            .vbo = gl.genBuffer()
        };
        gl.bindVertexArray(mesh.vao);
        gl.bindBuffer(mesh.vbo, .array_buffer);
        gl.bufferData(.array_buffer, Vertex, mesh.vertices, .static_draw);
        gl.bindBuffer(mesh.ebo, .element_array_buffer);
        gl.bufferData(.element_array_buffer, TriIndex, mesh.indices, .static_draw);
        gl.vertexAttribPointer(0, 3, .float, false, @sizeOf(Vertex), 0);
        gl.enableVertexAttribArray(0);
        self.mesh = mesh;
        return;
    }
};

pub const HeightMap = struct {
    vertices: []Vertex,
    size: [2]u32,
    mesh: Mesh,
    allocator: std.mem.Allocator,

    pub fn free(self: HeightMap) void {
        self.mesh.free(self.allocator);
    }

    pub fn new(allocator: std.mem.Allocator, vertices: []Vertex, size: [2]u32) HeightMap {
        return HeightMap{.allocator = allocator, .vertices = vertices, .size = size, .mesh = undefined};
    }

};

pub const World = struct {
    allocator: std.mem.Allocator,
    chunks_to_render: []Chunk,
    render_size: [3]u32,
    seed: u32,
    noise: Noise,

    pub fn new(allocator: std.mem.Allocator, render_size: [3]u32, seed: u32) World {
        return World{.allocator = allocator, .render_size = render_size, .chunks_to_render = undefined, .seed = seed, .noise = Noise{}};
    }
};

const Chunk = struct {
    pos: [3]i32,
    blocks: [64 * 64 * 64]BlockType = [_]BlockType{BlockType.air} ** 262144,
    bordering_chunk_ptrs: [4]?*Chunk = [_]?*Chunk{null, null, null, null},
    allocator: *const std.mem.Allocator,
    mesh: Mesh,

    const size: [3]i32 = [3]i32{64, 64, 64};

    pub fn generate(self: *Chunk, noise: *const Noise) !void {
        for (0..size[0]) |x| {
            for (0..size[2]) |z| {
                const n = noise.noise2(@floatFromInt(self.pos[0] * Chunk.size[0] + @as(i32, @intCast(x))), @floatFromInt(self.pos[2] * Chunk.size[2] + @as(i32, @intCast(z))));
                std.debug.print("{d}", .{n});
            }
        }
    }
};

test Chunk {
    const n = Noise{};
    var chunk = Chunk{.pos = .{0, 0, 0}, .mesh = undefined, .allocator = &std.testing.allocator};
    try chunk.generate(&n);
}

const BlockType = enum(u16) {
    air = 0,
    dirt = 1,
    _
};