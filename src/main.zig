const std = @import("std");
const gl = @import("zgl");
const glfw = @import("mach-glfw");
const zglm = @import("zglm");
const znoise = @import("znoise");
const lib = @import("./lib.zig");
var GPA = std.heap.GeneralPurposeAllocator(.{}){};

const vertex_shader_source = \\ #version 410 core
    \\ layout (location = 0) in vec3 aPos;
    \\ void main()
    \\ {
    \\   gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
    \\ }
;
const fragment_shader_source = \\ #version 410 core
    \\ out vec4 FragColor;
    \\ void main() {
    \\  FragColor = vec4(1.0, 1.0, 0.2, 1.0);
    \\ }
;

fn glGetProcAddress(p: glfw.GLProc, proc: [:0]const u8) ?gl.binding.FunctionPointer {
    _ = p;
    return glfw.getProcAddress(proc);
}

fn errorCallback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    std.log.err("glfw: {}: {s}\n", .{ error_code, description });
}

fn framebufferSizeCallback(_: glfw.Window, width: u32, height: u32) void {
    gl.viewport(0, 0, width, height);
}

pub fn main() !void {
    glfw.setErrorCallback(errorCallback);
    if (!glfw.init(.{})) {
        if (glfw.getError()) |err| {
            std.log.err("failed to initialise GLFW due to {}: {?s}", .{err.error_code, err.description});
            return err.error_code;
        }
    }
    defer glfw.terminate();

    const window = glfw.Window.create(640, 480, "GLFW Test", null, null, .{
        .opengl_profile = .opengl_core_profile,
        .context_version_major = 4,
        .context_version_minor = 5
    }) orelse {
        if (glfw.getError()) |err| {
            std.log.err("failed to create window due to {}: {?s}", .{err.error_code, err.description});
            return err.error_code;
        }
        std.log.err("failed to create window", .{});
        return;
    };
    defer window.destroy();

    glfw.makeContextCurrent(window);

    const proc: glfw.GLProc = undefined;
    try gl.loadExtensions(proc, glGetProcAddress);

    window.setFramebufferSizeCallback(framebufferSizeCallback);

    const verts = [_]f32{
        0.5, 0.5, 0,
        0.5, -0.5, 0,
        -0.5, -0.5, 0,
        -0.5, 0.5, 0
    };

    const inds = [_]u32{
        0, 1, 3,
        1, 2, 3
    };

    const vao = gl.genVertexArray();
    defer gl.deleteVertexArray(vao);

    const vbo = gl.genBuffer();
    defer gl.deleteBuffer(vbo);

    const ebo = gl.genBuffer();
    defer gl.deleteBuffer(ebo);

    gl.bindVertexArray(vao);
    gl.bindBuffer(vbo, .array_buffer);
    gl.bufferData(.array_buffer, f32, &verts, .static_draw);

    gl.bindBuffer(ebo, .element_array_buffer);
    gl.bufferData(.element_array_buffer, u32, &inds, .static_draw);

    gl.vertexAttribPointer(0, 3, .float, false, 3 * @sizeOf(f32), 0);
    gl.enableVertexAttribArray(0);

    const vertex_shader = gl.createShader(.vertex);
    defer gl.deleteShader(vertex_shader);
    gl.shaderSource(vertex_shader, 1, &.{vertex_shader_source});
    gl.compileShader(vertex_shader);

    const fragment_shader = gl.createShader(.fragment);
    defer gl.deleteShader(fragment_shader);
    gl.shaderSource(fragment_shader, 1, &.{fragment_shader_source});
    gl.compileShader(fragment_shader);

    const shader_program = gl.createProgram();
    defer gl.deleteProgram(shader_program);
    gl.attachShader(shader_program, vertex_shader);
    gl.attachShader(shader_program, fragment_shader);
    gl.linkProgram(shader_program);

    var heights = [_]f32{1, 2, 3, 1, 2, 3, 1, 2, 3};
    const hm = try lib.GridHeightMap.new(GPA.allocator(), heights[0..heights.len], .{3, 3}, .{1, 1});
    defer hm.free();

    while (!window.shouldClose()) {
        gl.clearColor(1, 0, 1, 1);
        gl.clear(.{.color = true});

        gl.useProgram(shader_program);
        gl.bindVertexArray(vao);
        gl.drawElements(.triangles, inds.len, .u32, 0);
        hm.render(shader_program);

        window.swapBuffers();
        glfw.pollEvents();
    }
}
