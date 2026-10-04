const std = @import("std");

const Translator = @import("translate_c").Translator;

/// SDL3 module.
sdl3: *std.Build.Module,
/// C translator used for SDL3.
translate_c: Translator,
/// Optional SDL lib to link against.
sdl_dep_lib: ?*std.Build.Step.Compile,
/// How to link the extension library.
linkage: std.lang.LinkMode,
/// If to use the system include path.
system_include_path: ?std.Build.LazyPath,
