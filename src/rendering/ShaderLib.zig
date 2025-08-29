// Shader library

const std = @import("std");

const c = @cImport({
    @cDefine("GLFW_INCLUDE_GL", "");
    @cDefine("GL_GLEXT_PROTOTYPES", "");    
    @cInclude("GLFW/glfw3.h");
});

const Shader = @This();

ID: c_uint,

pub fn create(arena: std.mem.Allocator, vertex_path: []const u8, fragment_path: []const u8) Shader {
    // Vertex Shader Creation
    // Vertex shaders run once per vertex and best I can tell, determine where the vertex will be on the screen.
    // So, it converts from 3D coordinates to 2D coordinates at the very minimum.
    // At least I think. It might just position them in 3D space?
    var vertexShader: c_uint = undefined;
    vertexShader = c.glCreateShader(c.GL_VERTEX_SHADER);
    defer c.glDeleteShader(vertexShader);

    // This is the setup for the fragment shader. The fragment shader runs once per pixel and determines the color of each pixel.
    // Simple!
    var fragmentShader: c_uint = undefined;
    fragmentShader = c.glCreateShader(c.GL_FRAGMENT_SHADER);
    defer c.glDeleteShader(fragmentShader);

    // Storing the result of selfExeDirPathAlloc in a variable to avoid calling it multiple times.
    const arena_path = std.fs.selfExeDirPathAlloc(arena) catch unreachable;
    const full_vertex_path = std.fs.path.join(arena, &.{
        arena_path,
        vertex_path,
    }) catch unreachable;


    const full_fragment_path = std.fs.path.join(arena, &.{
        arena_path,
        fragment_path,
    }) catch unreachable;


    const vertex_file = std.fs.openFileAbsolute(full_vertex_path, .{}) catch unreachable;
    const vertexShaderSource = vertex_file.readToEndAlloc(arena, 10 * 1024) catch unreachable;

    const vertexShaderSourceZ = arena.dupeZ(u8, vertexShaderSource);

    const fragment_file = std.fs.openFileAbsolute(full_fragment_path, .{}) catch unreachable;
    const fragmentShaderSource = fragment_file.readToEndAlloc(arena, 10 * 1024) catch unreachable;

    const fragmentShaderSourceZ = arena.dupeZ(u8, fragmentShaderSource);

    // Build and compile the vertex shader
    // Vertex shaders run once per vertex and best I can tell, determine where the vertex will be on the screen.
    // So, it converts from 3D coordinates to 2D coordinates at the very minimum.
    // At least I think. It might just position them in 3D space?
    c.glShaderSource(vertexShader, 1, @ptrCast(&vertexShaderSourceZ), null);
    c.glCompileShader(vertexShader);

    var success: c_int = undefined;

    // In C this would be a simple char array.
    // In zig it's a bit more complicated. We use a fixed-size array of u8.
    // The underscore before the u8 after the equal sign tells the compiler to infer the array size.
    // 512 in the value tells it to multiply the size by 512 bytes. The 0 means that the array is initialized with zeros.
    var infoLog: [512]u8 = [_]u8{0} ** 512;
    c.glGetShaderiv(vertexShader, c.GL_COMPILE_STATUS, &success);
    if (success == 0) {
        c.glGetShaderInfoLog(vertexShader, 512, 0, &infoLog);
        std.log.err("ERROR::SHADER::VERTEX::COMPILATION_FAILED\n{s}\n", .{infoLog[0 .. std.mem.indexOfScalar(u8, &infoLog, 0) orelse infoLog.len]});
    }

    // Fragment Shader setup
    c.glShaderSource(fragmentShader, 1, @ptrCast(&fragmentShaderSourceZ), null);
    c.glCompileShader(fragmentShader);
    c.glGetShaderiv(fragmentShader, c.GL_COMPILE_STATUS, &success);
    if (success == 0) {
        c.glGetShaderInfoLog(fragmentShader, 512, 0, &infoLog);
        std.log.err("ERROR::SHADER::FRAGMENT::COMPILATION_FAILED\n{s}\n", .{infoLog[0 .. std.mem.indexOfScalar(u8, &infoLog, 0) orelse infoLog.len]});
    }

    // This is the creation of the shader program.
    const shaderProgram = c.glCreateProgram();

    // These lines are where we attach the two shaders to the shader program, and then link them.
    c.glAttachShader(shaderProgram, vertexShader);
    c.glAttachShader(shaderProgram, fragmentShader);
    c.glLinkProgram(shaderProgram);

    // Checking for linking errors.
    c.glGetProgramiv(shaderProgram, c.GL_LINK_STATUS, &success);
    if (success == 0) {
        c.glGetProgramInfoLog(shaderProgram, 512, 0, &infoLog);
        std.log.err("ERROR::SHADER::VERTEX::COMPILATION_FAILED\n{s}\n", .{infoLog[0 .. std.mem.indexOfScalar(u8, &infoLog, 0) orelse infoLog.len]});
        std.process.exit(1);
    }

    return Shader{ .ID = shaderProgram };
}

pub fn use(self: Shader) void {
    c.glUseProgram(self.ID);
}

pub fn setBool(self: Shader, name: [*c]const u8, value: bool) void {
    c.glUniform1i(c.glGetUniformLocation(self.ID, name), if (value) 1 else 0);
}

pub fn setInt(self: Shader, name: [*c]const u8, value: u32) void {
    c.glUniform1i(c.glGetUniformLocation(self.ID, name), @as(c_int, value));
}

pub fn setFloat(self: Shader, name: [*c]const u8, value: f32) void {
    c.glUniform1f(c.glGetUniformLocation(self.ID, name), value);
}

pub fn setMat4f(self: Shader, name: [*c]const u8, value: [16]f32) void {
     const matLoc = c.glGetUniformLocation(self.ID, name);
    c.glUniformMatrix4fv(matLoc, 1, c.GL_FALSE, &value);
}
