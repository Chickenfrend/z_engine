const std = @import("std");

const builtin = @import("builtin");

const c = if (builtin.os.tag == .macos)
    @cImport({
        @cDefine("GLFW_INCLUDE_NONE", "");
        @cInclude("GLFW/glfw3.h");
    })
else
    @cImport({
        @cDefine("GLFW_INCLUDE_NONE", "");
        @cDefine("GL_GLEXT_PROTOTYPES", "");
        @cInclude("GLFW/glfw3.h");
    });

const PongState = @import("../PongState.zig").PongState;

pub const GraphicsApi = enum { opengl, vulkan };
pub const OpenGlVersion = struct {major: u32, minor: u32};

pub const Window = struct {
    handle: *c.GLFWwindow,
    height: u32,
    width: u32,
    api: GraphicsApi,

    pub fn init(width: u32, height: u32, comptime title: [:0]const u8, api: GraphicsApi) !Window {

        if (c.glfwInit() == 0) {
            std.debug.print("GLFW init failed!\n", .{});
            return error.GlfwInitFailed;
        }

        switch(api) {
            .opengl => {
                _ = c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
                _ = c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
                _ = c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);

                // I think this is for mac only.
                _ = c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GLFW_TRUE);
            },
            .vulkan => {
                @panic("Vulkan not yet supported");
            }
        }

        const handle = c.glfwCreateWindow(@intCast(width), @intCast(height), title, null, null) orelse @panic("Could not open window!");


        if (api == .opengl) {
            _ = c.glfwMakeContextCurrent(handle);
        }
        return Window{
            .handle = handle,
            .width = width,
            .height = height,
            .api = api,
        };
    }

    pub fn shouldClose(self: *Window) bool {
        return c.glfwWindowShouldClose(self.handle) != 0;
    }

    pub fn swapBuffers(self: *Window) void {
       c.glfwSwapBuffers(self.handle); 
    }
    pub fn pollEvents(self: *Window) void {
        _ = self;
        c.glfwPollEvents();
    }
    pub fn deinit(self: *Window) void {
        c.glfwDestroyWindow(self.handle);
        c.glfwTerminate();
    }

    // This should be moved to its own module
    pub fn processInput(self: *Window, pong: *PongState, dt: f32) void {
        if (c.glfwGetKey(self.handle, c.GLFW_KEY_ESCAPE) == c.GLFW_PRESS) {
            c.glfwSetWindowShouldClose(self.handle, 1);
        }
        if (c.glfwGetKey(self.handle, c.GLFW_KEY_W) == c.GLFW_PRESS) {
            pong.moveLeftPaddle(-1.0, dt);
        }
        if (c.glfwGetKey(self.handle, c.GLFW_KEY_S) == c.GLFW_PRESS) {
            pong.moveLeftPaddle(1.0, dt);
        }
        if (c.glfwGetKey(self.handle, c.GLFW_KEY_UP) == c.GLFW_PRESS) {
            pong.moveRightPaddle(-1.0, dt);
        }
        if (c.glfwGetKey(self.handle, c.GLFW_KEY_DOWN) == c.GLFW_PRESS) {
            pong.moveRightPaddle(1.0, dt);
        }
    }

    pub fn getFramebufferSize(self: *Window) [2]u32 {
        var width: c_int = 0;
        var height: c_int = 0;
        c.glfwGetFramebufferSize(self.handle, &width, &height);
        return .{ @intCast(width), @intCast(height) };
    }
};
