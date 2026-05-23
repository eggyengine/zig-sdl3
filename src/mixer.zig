const audio = @import("audio.zig");
const c = @import("c");
const errors = @import("errors.zig");
const io_stream = @import("io_stream.zig");
const properties = @import("properties.zig");
const std = @import("std");

comptime {
    if (!@hasDecl(c, "MIX_Init"))
        @compileError("The ext_mixer feature is either not enabled or not working!");
}

/// SDL_mixer version information.
pub const Version = struct {
    value: c_int,
    /// SDL_mixer version compiled against.
    pub const compiled_against = Version{ .value = c.SDL_MIXER_VERSION };

    /// Create an SDL_mixer version number.
    pub fn make(
        major: u32,
        minor: u32,
        micro: u32,
    ) Version {
        const ret = c.SDL_VERSIONNUM(
            @intCast(major),
            @intCast(minor),
            @intCast(micro),
        );
        return Version{ .value = ret };
    }

    /// Major version number.
    pub fn getMajor(
        self: Version,
    ) u32 {
        const ret = c.SDL_VERSIONNUM_MAJOR(
            self.value,
        );
        return @intCast(ret);
    }

    /// Minor version number.
    pub fn getMinor(
        self: Version,
    ) u32 {
        const ret = c.SDL_VERSIONNUM_MINOR(
            self.value,
        );
        return @intCast(ret);
    }

    /// Micro version number.
    pub fn getMicro(
        self: Version,
    ) u32 {
        const ret = c.SDL_VERSIONNUM_MICRO(
            self.value,
        );
        return @intCast(ret);
    }

    /// Check if the SDL_mixer version is at least greater than the given one.
    pub fn atLeast(
        major: u32,
        minor: u32,
        micro: u32,
    ) bool {
        const ret = c.SDL_MIXER_VERSION_ATLEAST(
            @intCast(major),
            @intCast(minor),
            @intCast(micro),
        );
        return ret;
    }

    /// Get the version of SDL_mixer that is linked against your program. Possibly different than the compiled against version.
    pub fn get() Version {
        const ret = c.MIX_Version();
        return Version{ .value = ret };
    }
};

/// Initialize the SDL_mixer library.
///
/// ## Remarks
/// This must be successfully called once before (almost) any other SDL_mixer function can be used.
/// It is safe to call this multiple times; the library will only initialize once, and won't deinitialize until `mixer.quit()` has been called a matching number of times.
/// Extra attempts to init report success.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL_mixer 3.0.0.
pub fn init() !void {
    const ret = c.MIX_Init();
    return errors.wrapCallBool(ret);
}

/// Deinitialize the SDL_mixer library.
///
/// ## Remarks
/// This must be called when done with the library, probably at the end of your program.
/// It is safe to call this multiple times; the library will only deinitialize once, when this function is called the same number of times as `mixer.init()` was successfully called.
/// Once you have successfully deinitialized the library, it is safe to call `mixer.init()` to reinitialize it for further use.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL_mixer 3.0.0.
pub fn quit() void {
    c.MIX_Quit();
}

/// Options that control how a track begins playing.
///
/// ## Remarks
/// All fields are optional; a `null` field uses SDL_mixer's default behavior for that setting.
/// This maps to the `MIX_PROP_PLAY_*` properties that `Track.play()` accepts.
///
/// ## Version
/// This type is provided by zig-sdl3.
pub const PlayOptions = struct {
    /// Number of times to loop the track after the first play, or `-1` to loop forever.
    loops: ?i64 = null,
    /// Fade the track in over this many milliseconds.
    fade_in_milliseconds: ?i64 = null,
    /// Start playback this many milliseconds into the audio.
    start_millisecond: ?i64 = null,
    /// Stop playback after this many milliseconds have been mixed.
    max_milliseconds: ?i64 = null,

    /// Convert to an SDL properties group.
    pub fn toProperties(
        self: PlayOptions,
    ) !properties.Group {
        const ret = try properties.Group.init();
        if (self.loops) |val| try ret.set(
            c.MIX_PROP_PLAY_LOOPS_NUMBER,
            .{ .number = val },
        );
        if (self.fade_in_milliseconds) |val| try ret.set(
            c.MIX_PROP_PLAY_FADE_IN_MILLISECONDS_NUMBER,
            .{ .number = val },
        );
        if (self.start_millisecond) |val| try ret.set(
            c.MIX_PROP_PLAY_START_MILLISECOND_NUMBER,
            .{ .number = val },
        );
        if (self.max_milliseconds) |val| try ret.set(
            c.MIX_PROP_PLAY_MAX_MILLISECONDS_NUMBER,
            .{ .number = val },
        );
        return ret;
    }
};

/// Static audio data that can be assigned to one or more tracks for playback.
///
/// ## Remarks
/// This is an opaque datatype, to be treated by the app as a handle.
/// An audio object holds the decoded (or to-be-decoded) sound data;
/// assign it to a `mixer.Track` to actually play it.
///
/// ## Version
/// This datatype is available since SDL_mixer 3.0.0.
pub const Audio = struct {
    value: *c.MIX_Audio,

    /// Dispose of a previously-loaded audio object.
    ///
    /// ## Function Parameters
    /// * `self`: The audio object to destroy.
    ///
    /// ## Remarks
    /// Tracks that are still using this audio object will stop playing.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn deinit(
        self: Audio,
    ) void {
        c.MIX_DestroyAudio(
            self.value,
        );
    }

    /// Get the total playback duration of an audio object, in sample frames.
    ///
    /// ## Function Parameters
    /// * `self`: The audio object to query.
    ///
    /// ## Return Value
    /// Returns the duration in sample frames, or a negative value if the duration is unknown or infinite.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn getDuration(
        self: Audio,
    ) i64 {
        const ret = c.MIX_GetAudioDuration(
            self.value,
        );
        return @intCast(ret);
    }

    /// Get the audio format of an audio object.
    ///
    /// ## Function Parameters
    /// * `self`: The audio object to query.
    ///
    /// ## Return Value
    /// Returns the audio specification of the audio object.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn getFormat(
        self: Audio,
    ) !audio.Spec {
        var spec: c.SDL_AudioSpec = undefined;
        const ret = c.MIX_GetAudioFormat(
            self.value,
            &spec,
        );
        try errors.wrapCallBool(ret);
        return audio.Spec.fromSdl(spec);
    }
};

/// An object that mixes audio and (optionally) sends it to an audio device.
///
/// ## Remarks
/// This is an opaque datatype, to be treated by the app as a handle.
/// A mixer owns the audio objects and tracks created through it;
/// destroying the mixer destroys them too.
///
/// ## Version
/// This datatype is available since SDL_mixer 3.0.0.
pub const Mixer = struct {
    value: *c.MIX_Mixer,

    /// Create a mixer that plays through an audio device.
    ///
    /// ## Function Parameters
    /// * `device`: The audio device to open, such as `audio.Device.default_playback`.
    /// * `spec`: The audio format to mix in, or `null` to let SDL_mixer choose a reasonable default.
    ///
    /// ## Return Value
    /// Returns a new `mixer.Mixer`.
    ///
    /// ## Remarks
    /// When you are done with the returned mixer, dispose of it with `deinit()`.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn init(
        device: audio.Device,
        spec: ?audio.Spec,
    ) !Mixer {
        const spec_sdl: c.SDL_AudioSpec = if (spec) |val| val.toSdl() else undefined;
        const ret = c.MIX_CreateMixerDevice(
            device.value,
            if (spec != null) &spec_sdl else null,
        );
        return Mixer{ .value = try errors.wrapCallNull(*c.MIX_Mixer, ret) };
    }

    /// Dispose of a previously-created mixer.
    ///
    /// ## Function Parameters
    /// * `self`: The mixer to destroy.
    ///
    /// ## Remarks
    /// This also destroys all tracks and audio objects created through this mixer.
    ///
    /// ## Thread Safety
    /// You should not operate on the same mixer from multiple threads at the same time without supplying a serialization mechanism.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn deinit(
        self: Mixer,
    ) void {
        c.MIX_DestroyMixer(
            self.value,
        );
    }

    /// Get the audio format the mixer is mixing in.
    ///
    /// ## Function Parameters
    /// * `self`: The mixer to query.
    ///
    /// ## Return Value
    /// Returns the audio specification of the mixer.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn getFormat(
        self: Mixer,
    ) !audio.Spec {
        var spec: c.SDL_AudioSpec = undefined;
        const ret = c.MIX_GetMixerFormat(
            self.value,
            &spec,
        );
        try errors.wrapCallBool(ret);
        return audio.Spec.fromSdl(spec);
    }

    /// Set the master gain (volume) of the mixer.
    ///
    /// ## Function Parameters
    /// * `self`: The mixer to modify.
    /// * `gain`: The new gain, where `0.0` is silence and `1.0` is full volume. Values above `1.0` are allowed.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn setGain(
        self: Mixer,
        gain: f32,
    ) !void {
        const ret = c.MIX_SetMixerGain(
            self.value,
            gain,
        );
        return errors.wrapCallBool(ret);
    }

    /// Get the master gain (volume) of the mixer.
    ///
    /// ## Function Parameters
    /// * `self`: The mixer to query.
    ///
    /// ## Return Value
    /// Returns the current master gain.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn getGain(
        self: Mixer,
    ) f32 {
        return c.MIX_GetMixerGain(
            self.value,
        );
    }

    /// Load audio data from a filesystem path.
    ///
    /// ## Function Parameters
    /// * `self`: The mixer the audio will be used with.
    /// * `path`: The path on the filesystem to load the audio from.
    /// * `predecode`: If `true`, fully decode the audio now instead of decoding it during playback.
    ///
    /// ## Return Value
    /// Returns a new `mixer.Audio`. The caller must call `deinit()` on it when done.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn loadAudio(
        self: Mixer,
        path: [:0]const u8,
        predecode: bool,
    ) !Audio {
        const ret = c.MIX_LoadAudio(
            self.value,
            path,
            predecode,
        );
        return Audio{ .value = try errors.wrapCallNull(*c.MIX_Audio, ret) };
    }

    /// Load audio data from an `io_stream.Stream`.
    ///
    /// ## Function Parameters
    /// * `self`: The mixer the audio will be used with.
    /// * `stream`: The stream to load the audio from.
    /// * `predecode`: If `true`, fully decode the audio now instead of decoding it during playback.
    /// * `close_when_done`: If `true`, close the stream when done with it (whether this call succeeds or not).
    ///
    /// ## Return Value
    /// Returns a new `mixer.Audio`. The caller must call `deinit()` on it when done.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn loadAudioIo(
        self: Mixer,
        stream: io_stream.Stream,
        predecode: bool,
        close_when_done: bool,
    ) !Audio {
        const ret = c.MIX_LoadAudio_IO(
            self.value,
            stream.value,
            predecode,
            close_when_done,
        );
        return Audio{ .value = try errors.wrapCallNull(*c.MIX_Audio, ret) };
    }

    /// Create an audio object that produces a sine wave.
    ///
    /// ## Function Parameters
    /// * `self`: The mixer the audio will be used with.
    /// * `hz`: The frequency of the sine wave, in Hz.
    /// * `amplitude`: The amplitude of the sine wave, from `0.0` (silence) to `1.0` (full volume).
    /// * `milliseconds`: The duration of the generated audio in milliseconds, or `null` to generate infinite audio that plays forever.
    ///
    /// ## Return Value
    /// Returns a new `mixer.Audio`. The caller must call `deinit()` on it when done.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn createSineWaveAudio(
        self: Mixer,
        hz: i32,
        amplitude: f32,
        milliseconds: ?i64,
    ) !Audio {
        const ret = c.MIX_CreateSineWaveAudio(
            self.value,
            @intCast(hz),
            amplitude,
            if (milliseconds) |ms| @intCast(ms) else -1,
        );
        return Audio{ .value = try errors.wrapCallNull(*c.MIX_Audio, ret) };
    }
};

/// A logical grouping of tracks that can be operated on collectively.
///
/// ## Remarks
/// This is an opaque datatype, to be treated by the app as a handle.
///
/// ## Version
/// This datatype is available since SDL_mixer 3.0.0.
pub const Group = struct {
    value: *c.MIX_Group,

    /// Create a new group of tracks on a mixer.
    ///
    /// ## Function Parameters
    /// * `mixer`: The mixer to create the group on.
    ///
    /// ## Return Value
    /// Returns a new `mixer.Group`. The caller must call `deinit()` on it when done.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn init(
        mixer: Mixer,
    ) !Group {
        const ret = c.MIX_CreateGroup(
            mixer.value,
        );
        return Group{ .value = try errors.wrapCallNull(*c.MIX_Group, ret) };
    }

    /// Dispose of a previously-created group.
    ///
    /// ## Function Parameters
    /// * `self`: The group to destroy.
    ///
    /// ## Remarks
    /// Tracks in this group are not destroyed; they are simply no longer in a group.
    ///
    /// ## Thread Safety
    /// You should not operate on the same group from multiple threads at the same time without supplying a serialization mechanism.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn deinit(
        self: Group,
    ) void {
        c.MIX_DestroyGroup(
            self.value,
        );
    }
};

/// An individual audio source that can be played through a mixer.
///
/// ## Remarks
/// This is an opaque datatype, to be treated by the app as a handle.
/// A track gets its sound from an assigned `mixer.Audio` and is then played, paused, faded, etc.
///
/// ## Version
/// This datatype is available since SDL_mixer 3.0.0.
pub const Track = struct {
    value: *c.MIX_Track,

    /// Create a new track on a mixer.
    ///
    /// ## Function Parameters
    /// * `mixer`: The mixer to create the track on.
    ///
    /// ## Return Value
    /// Returns a new `mixer.Track`. The caller must call `deinit()` on it when done.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn init(
        mixer: Mixer,
    ) !Track {
        const ret = c.MIX_CreateTrack(
            mixer.value,
        );
        return Track{ .value = try errors.wrapCallNull(*c.MIX_Track, ret) };
    }

    /// Dispose of a previously-created track.
    ///
    /// ## Function Parameters
    /// * `self`: The track to destroy.
    ///
    /// ## Thread Safety
    /// You should not operate on the same track from multiple threads at the same time without supplying a serialization mechanism.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn deinit(
        self: Track,
    ) void {
        c.MIX_DestroyTrack(
            self.value,
        );
    }

    /// Assign an audio object to a track as its sound source.
    ///
    /// ## Function Parameters
    /// * `self`: The track to modify.
    /// * `audio_data`: The audio object to assign to the track.
    ///
    /// ## Thread Safety
    /// You should not operate on the same track from multiple threads at the same time without supplying a serialization mechanism.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn setAudio(
        self: Track,
        audio_data: Audio,
    ) !void {
        const ret = c.MIX_SetTrackAudio(
            self.value,
            audio_data.value,
        );
        return errors.wrapCallBool(ret);
    }

    /// Start (or restart) playback of a track.
    ///
    /// ## Function Parameters
    /// * `self`: The track to play.
    /// * `options`: How the track should begin playing.
    ///
    /// ## Thread Safety
    /// You should not operate on the same track from multiple threads at the same time without supplying a serialization mechanism.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn play(
        self: Track,
        options: PlayOptions,
    ) !void {
        const group = try options.toProperties();
        defer group.deinit();
        const ret = c.MIX_PlayTrack(
            self.value,
            group.value,
        );
        return errors.wrapCallBool(ret);
    }

    /// Stop playback of a track.
    ///
    /// ## Function Parameters
    /// * `self`: The track to stop.
    /// * `fade_out_frames`: Fade the track out over this many sample frames, or `0` to stop immediately.
    ///
    /// ## Thread Safety
    /// You should not operate on the same track from multiple threads at the same time without supplying a serialization mechanism.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn stop(
        self: Track,
        fade_out_frames: i64,
    ) !void {
        const ret = c.MIX_StopTrack(
            self.value,
            @intCast(fade_out_frames),
        );
        return errors.wrapCallBool(ret);
    }

    /// Pause playback of a track.
    ///
    /// ## Function Parameters
    /// * `self`: The track to pause.
    ///
    /// ## Thread Safety
    /// You should not operate on the same track from multiple threads at the same time without supplying a serialization mechanism.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn pause(
        self: Track,
    ) !void {
        const ret = c.MIX_PauseTrack(
            self.value,
        );
        return errors.wrapCallBool(ret);
    }

    /// Resume playback of a paused track.
    ///
    /// ## Function Parameters
    /// * `self`: The track to resume.
    ///
    /// ## Thread Safety
    /// You should not operate on the same track from multiple threads at the same time without supplying a serialization mechanism.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn resumeTrack(
        self: Track,
    ) !void {
        const ret = c.MIX_ResumeTrack(
            self.value,
        );
        return errors.wrapCallBool(ret);
    }

    /// Check if a track is currently playing.
    ///
    /// ## Function Parameters
    /// * `self`: The track to query.
    ///
    /// ## Return Value
    /// Returns `true` if the track is playing, `false` otherwise.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn isPlaying(
        self: Track,
    ) bool {
        return c.MIX_TrackPlaying(
            self.value,
        );
    }

    /// Check if a track is currently paused.
    ///
    /// ## Function Parameters
    /// * `self`: The track to query.
    ///
    /// ## Return Value
    /// Returns `true` if the track is paused, `false` otherwise.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn isPaused(
        self: Track,
    ) bool {
        return c.MIX_TrackPaused(
            self.value,
        );
    }

    /// Set the gain (volume) of a track.
    ///
    /// ## Function Parameters
    /// * `self`: The track to modify.
    /// * `gain`: The new gain, where `0.0` is silence and `1.0` is full volume. Values above `1.0` are allowed.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn setGain(
        self: Track,
        gain: f32,
    ) !void {
        const ret = c.MIX_SetTrackGain(
            self.value,
            gain,
        );
        return errors.wrapCallBool(ret);
    }

    /// Get the gain (volume) of a track.
    ///
    /// ## Function Parameters
    /// * `self`: The track to query.
    ///
    /// ## Return Value
    /// Returns the current track gain.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn getGain(
        self: Track,
    ) f32 {
        return c.MIX_GetTrackGain(
            self.value,
        );
    }

    /// Assign a track to a group, or remove it from its group.
    ///
    /// ## Function Parameters
    /// * `self`: The track to modify.
    /// * `group`: The group to assign the track to, or `null` to remove it from any group.
    ///
    /// ## Thread Safety
    /// You should not operate on the same track from multiple threads at the same time without supplying a serialization mechanism.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn setGroup(
        self: Track,
        group: ?Group,
    ) !void {
        const ret = c.MIX_SetTrackGroup(
            self.value,
            if (group) |g| g.value else null,
        );
        return errors.wrapCallBool(ret);
    }

    /// Add a tag to a track.
    ///
    /// ## Function Parameters
    /// * `self`: The track to tag.
    /// * `name`: The tag to add to the track.
    ///
    /// ## Remarks
    /// Tags let you operate on several tracks at once by referring to them by a shared name.
    ///
    /// ## Thread Safety
    /// You should not operate on the same track from multiple threads at the same time without supplying a serialization mechanism.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn tag(
        self: Track,
        name: [:0]const u8,
    ) !void {
        const ret = c.MIX_TagTrack(
            self.value,
            name,
        );
        return errors.wrapCallBool(ret);
    }

    /// Remove a tag from a track.
    ///
    /// ## Function Parameters
    /// * `self`: The track to untag.
    /// * `name`: The tag to remove from the track.
    ///
    /// ## Thread Safety
    /// You should not operate on the same track from multiple threads at the same time without supplying a serialization mechanism.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn untag(
        self: Track,
        name: [:0]const u8,
    ) void {
        c.MIX_UntagTrack(
            self.value,
            name,
        );
    }
};

test "mixer" {
    std.testing.refAllDecls(@This());
}
