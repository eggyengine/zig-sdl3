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

/// A callback that fires when a `Group` has completed mixing.
///
/// ## Function Parameters
/// * `user_data`: User data for personal use.
/// * `group`: The group that is being mixed.
/// * `spec`: The format of the data in `pcm`.
/// * `pcm`: The raw PCM data in `f32` format.
///
/// ## Remarks
/// This callback is fired when a mixing group has finished mixing: all tracks in the group have mixed into a single buffer and are prepared to be mixed
/// into all other groups for the final mix output.
///
/// The audio data passed through here is not const data; the app is permitted to change it in any way it likes, and those changes will propagate through the mixing pipeline.
///
/// An audiospec is provided.
/// Different groups might be in different formats, and an app needs to be able to handle that,
/// but SDL mixer always does its mixing work in 32-bit float samples, even if the inputs or final output are not floating point.
/// As such, `spec.format` will always be `floating_32_bit` and pcm hardcoded to be a float pointer.
///
/// The `samples` is the number of float values pointed to by pcm: samples, not sample frames!
/// There are no promises how many samples will be provided per-callback, and this number can vary wildly from call to call, depending on many factors.
///
/// ## Version
/// This datatype is available since SDL_mixer 3.0.0.
pub fn GroupMixCallback(comptime UserData: type) type {
    return *const fn (
        user_data: ?*UserData,
        group: Group,
        spec: audio.Spec,
        pcm: []f32,
    ) void;
}

/// A callback that fires when all mixing has completed.
///
/// ## Function Parameters
/// * `user_data`: User data for personal use.
/// * `mixer`: The mixer that is generating audio.
/// * `spec`: The format of the data in `pcm`.
/// * `pcm`: The raw PCM data in `f32` format.
///
/// ## Remarks
/// This callback is fired when the mixer has completed all its work.
/// If this mixer was created with `Mixer.initDevice`, the data provided by this callback is what is being sent to the audio hardware,
/// minus last conversions for format requirements.
/// If this mixer was created with `Mixer.init`, this is what is being output from `Mixer.generate`, after final conversions.
///
/// The audio data passed through here is not const data; the app is permitted to change it in any way it likes, and those changes will replace the final mixer pipeline output.
///
/// An audiospec is provided.
/// Different groups might be in different formats, and an app needs to be able to handle that,
/// but SDL mixer always does its mixing work in 32-bit float samples, even if the inputs or final output are not floating point.
/// As such, `spec.format` will always be `floating_32_bit` and pcm hardcoded to be a float pointer.
///
/// The `samples` is the number of float values pointed to by pcm: samples, not sample frames!
/// There are no promises how many samples will be provided per-callback, and this number can vary wildly from call to call, depending on many factors.
///
/// ## Version
/// This datatype is available since SDL_mixer 3.0.0.
pub fn PostMixCallback(comptime UserData: type) type {
    return *const fn (
        user_data: ?*UserData,
        mixer: Mixer,
        spec: audio.Spec,
        pcm: []f32,
    ) void;
}

/// A callback that fires when a track is mixing at various stages.
///
/// ## Function Parameters
/// * `user_data`: User data for personal use.
/// * `track`: The track that is being mixed.
/// * `spec`: The format of the data in `pcm`.
/// * `pcm`: The raw PCM data in `f32` format.
///
/// ## Remarks
/// This callback is fired for different parts of the mixing pipeline, and gives the app visbility into the audio data that is being generated at various stages.
///
/// The audio data passed through here is not const data; the app is permitted to change it in any way it likes, and those changes will propagate through the mixing pipeline.
///
/// An audiospec is provided.
/// Different groups might be in different formats, and an app needs to be able to handle that,
/// but SDL mixer always does its mixing work in 32-bit float samples, even if the inputs or final output are not floating point.
/// As such, `spec.format` will always be `floating_32_bit` and pcm hardcoded to be a float pointer.
///
/// The `samples` is the number of float values pointed to by pcm: samples, not sample frames!
/// There are no promises how many samples will be provided per-callback, and this number can vary wildly from call to call, depending on many factors.
///
/// Making changes to the track during this callback is undefined behavior.
/// Change the data in pcm but not the track itself.
///
/// ## Version
/// This datatype is available since SDL_mixer 3.0.0.
pub fn TrackMixCallback(comptime UserData: type) type {
    return *const fn (
        user_data: ?*UserData,
        track: Track,
        spec: audio.Spec,
        pcm: []f32,
    ) void;
}

/// A callback that fires when a MIX Track is stopped.
///
/// ## Function Parameters
/// * `user_data`: User data for personal use.
/// * `track`: The track that has stopped.
///
/// ## Remarks
/// This callback is fired when a track completes playback, either because it ran out of data to mix (and all loops were completed as well), or it was explicitly stopped by the app.
/// Pausing a track will not fire this callback.
///
/// It is legal to adjust the track, including changing its input and restarting it.
/// If this is done because it ran out of data in the middle of mixing, the mixer will start mixing the new track state in its current run without any gap in the audio.
///
/// This callback will not fire when a playing track is destroyed.
///
/// ## Version
/// This datatype is available since SDL_mixer 3.0.0.
pub fn TrackStoppedCallback(comptime UserData: type) type {
    return *const fn (
        user_data: ?*UserData,
        track: Track,
    ) void;
}

/// An opaque object that represents audio data.
///
/// ## Remarks
/// Generally you load audio data (in whatever file format) into SDL_mixer with `Audio.load` or one of its several variants, producing an `Audio` object.
///
/// An `Audio` represents static audio data; it could be background music, or maybe a laser gun sound effect.
/// It is loaded into RAM and can be played multiple times, possibly on different tracks at the same time.
///
/// Unlike most other objects, `Audio` objects can be shared between mixers.
///
/// ## Version
/// This datatype is available since SDL_mixer 3.0.0.
pub const Audio = extern struct {
    value: *c.MIX_Audio,

    /// Destroy the specified audio.
    ///
    /// ## Function Parameters
    /// * `self`: The audio object to destroy.
    ///
    /// ## Remarks
    /// Audio is reference-counted internally, so this function only unrefs it.
    /// If doing so causes the reference count to drop to zero, the audio will be deallocated.
    /// This allows the system to safely operate if the audio is still assigned to a `Track` at the time of destruction.
    /// The actual destroying will happen when the track stops using it.
    ///
    /// But from the caller's perspective, once this function is called, it should assume the audio pointer has become invalid.
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

    /// Convert sample frames for a MIX Audio's format to milliseconds.
    ///
    /// ## Function Parameters
    /// * `self`: The audio to query.
    /// * `frames`: The audio-specific sample frames to convert to milliseconds.
    ///
    /// ## Return Value
    /// Returns converted number of milliseconds.
    ///
    /// ## Remarks
    /// This calculates time based on the audio's initial format, even if the format would change mid-stream.
    ///
    /// Sample frames are more precise than milliseconds, so out of necessity, this function will approximate by rounding down to the closest full millisecond.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn framesToMs(
        self: Audio,
        frames: usize,
    ) !usize {
        return @intCast(try errors.wrapCall(c.Sint64, c.MIX_AudioFramesToMS(self.value, @intCast(frames)), -1));
    }

    /// Get the total playback duration of an audio object in sample frames.
    ///
    /// ## Function Parameters
    /// * `self`: The audio to query.
    ///
    /// ## Return Value
    /// Returns the duration in sample frames, or if its infinite, or `null` if unknown.
    ///
    /// ## Remarks
    /// This information is also available via the `duration_frames` property, but it's common enough to provide a simple accessor function.
    ///
    /// This reports the length of the data in sample frames, so sample-perfect mixing can be possible.
    /// Sample frames are only meaningful as a measure of time if the sample rate (frequency) is also known.
    /// To convert from sample frames to milliseconds, use `Audio.framesToMs`.
    ///
    /// Not all audio file formats can report the complete length of the data they will produce through decoding: some can't calculate it, some might produce infinite audio.
    ///
    /// Also, some file formats can only report duration as a unit of time, which means SDL mixer might have to estimate sample frames from that information.
    /// With less precision, the reported duration might be off by a few sample frames in either direction.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn getDuration(
        self: Audio,
    ) ?AudioDuration {
        const ret = c.MIX_GetAudioDuration(
            self.value,
        );
        if (ret == -1)
            return null;
        if (ret == -2)
            return .{ .infinite = {} };
        return .{ .frames = @intCast(ret) };
    }

    /// Get the audio format of an audio object.
    ///
    /// ## Function Parameters
    /// * `self`: The audio object to query.
    ///
    /// ## Return Value
    /// Returns the audio specification of the audio object.
    ///
    /// ## Remarks
    /// Note that some audio files can change format in the middle; some explicitly support this, but a more common example is two MP3 files concatenated together.
    /// In many cases, SDL_mixer will correctly handle these sort of files, but this function will only report the initial format a file uses.
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

    /// Create an audio object that produces a sine wave.
    ///
    /// ## Function Parameters
    /// * `self`: The mixer the audio will be used with.
    /// * `hz`: The frequency of the sine wave, in Hz.
    /// * `amplitude`: The amplitude of the sine wave, from `0` (silence) to `1` (full volume).
    /// * `milliseconds`: The duration of the generated audio in milliseconds, or `null` to generate infinite audio that plays forever.
    ///
    /// ## Return Value
    /// Returns a new `mixer.Audio`.
    /// The caller must call `deinit()` on it when done.
    ///
    /// ## Remarks
    /// This is useful just to have something to play, perhaps for testing or debugging purposes.
    ///
    /// You specify its frequency in Hz (determines the pitch of the sinewave's audio) and amplitude (determines the volume of the sinewave: `1` is very loud, `0` is silent).
    ///
    /// A number of milliseconds of audio to generate can be specified.
    /// Specifying a value less than zero will generate infinite audio (when assigned to a `Track`, the sinewave will play forever).
    ///
    /// `Audio` objects can be shared between multiple mixers.
    /// The mixer parameter just suggests the most likely mixer to use this audio, in case some optimization might be applied, but this is not required, and a `null` mixer may be specified.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn initSineWaveAudio(
        self: ?Mixer,
        hz: u31,
        amplitude: f32,
        milliseconds: ?usize,
    ) !Audio {
        const ret = c.MIX_CreateSineWaveAudio(
            if (self) |val| val.value else null,
            @intCast(hz),
            amplitude,
            if (milliseconds) |ms| @intCast(ms) else -1,
        );
        return Audio{ .value = try errors.wrapCallNull(*c.MIX_Audio, ret) };
    }

    /// Convert milliseconds to sample frames for an Audio's format.
    ///
    /// ## Function Parameters
    /// * `self`: The audio to query.
    /// * `ms`: The milliseconds to convert to audio-specific sample frames.
    ///
    /// ## Return Value
    /// Returns converted number of sample frames.
    ///
    /// ## Remarks
    /// This calculates time based on the audio's initial format, even if the format would change mid-stream.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn msToFrames(
        self: Audio,
        ms: usize,
    ) !usize {
        return @intCast(try errors.wrapCall(c.Sint64, c.MIX_AudioMSToFrames(self.value, @intCast(ms)), -1));
    }
};

/// An opaque object that represents an audio decoder.
///
/// ## Remarks
/// Most apps won't need this, as SDL mixer's usual interfaces will decode audio as needed.
/// However, if one wants to decode an audio file into a memory buffer without playing it, this interface offers that.
///
/// These objects are created with `AudioDecoder.init` or `AudioDecoder.initIo` and then can use `AudioDecoder.decode` to retrieve the raw PCM data.
///
/// ## Version
/// This struct is available since SDL_mixer 3.0.0.
pub const AudioDecoder = extern struct {
    value: *c.MIX_AudioDecoder,

    /// Decode more audio from a decoder.
    ///
    /// ## Function Parameters
    /// * `self`: The decoder from which to retrieve more data.
    /// * `buffer`: The memory buffer to store decoded audio.
    /// * `spec`: The format that audio data will be stored to `buffer`.
    ///
    /// ## Return Value
    /// Returns the bytes that have been decoded or `null` if end of file.
    ///
    /// ## Remarks
    /// Data is decoded on demand in whatever format is requested.
    /// The format is permitted to change between calls.
    ///
    /// This function will return the bytes decoded, which may be less than requested if there was an error or end-of-file.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn decode(
        self: AudioDecoder,
        buffer: []u8,
        spec: audio.Spec,
    ) !?[]u8 {
        const ret: usize = @intCast(try errors.wrapCall(c_int, c.MIX_DecodeAudio(self.value, buffer.ptr, @intCast(buffer.len), &spec.toSdl()), -1));
        if (ret == 0)
            return null;
        return buffer[0..ret];
    }

    /// Destroy the specified audio decoder.
    ///
    /// ## Function Parameters
    /// * `self`: The audio to destroy.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// Version
    /// ## This function is available since SDL_mixer 3.0.0.
    pub fn deinit(
        self: AudioDecoder,
    ) void {
        c.MIX_DestroyAudioDecoder(self.value);
    }

    /// Query the initial audio format of an audio decoder.
    ///
    /// ## Function Parameters
    /// * `self`: The audio decoder to query.
    ///
    /// ## Return Value
    /// Returns the audio format details.
    ///
    /// ## Remarks
    /// Note that some audio files can change format in the middle; some explicitly support this, but a more common example is two MP3 files concatenated together.
    /// In many cases, SDL mixer will correctly handle these sort of files, but this function will only report the initial format a file uses.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn getFormat(
        self: AudioDecoder,
    ) !audio.Spec {
        var ret: c.SDL_AudioSpec = undefined;
        try errors.wrapCallBool(c.MIX_GetAudioDecoderFormat(self.value, &ret));
        return audio.Spec.fromSdl(ret);
    }

    /// Create an audio decoder from a path on the filesystem.
    ///
    /// ## Function Parameters
    /// * `path`: The path on the filesystem from which to load data.
    /// * `props`: Decoder-specific properties if desired.
    ///
    /// ## Return Value
    /// Returns an audio decoder, ready to decode.
    ///
    /// ## Remarks
    /// Most apps won't need this, as SDL mixer's usual interfaces will decode audio as needed.
    /// However, if one wants to decode an audio file into a memory buffer without playing it, this interface offers that.
    ///
    /// This function allows properties to be specified.
    /// This is intended to supply file-specific settings, such as where to find SoundFonts for a MIDI file, etc.
    /// In most cases, the caller should pass null to specify no extra properties.
    ///
    /// When done with the audio decoder, it can be destroyed with `AudioDecoder.deinit`
    ///
    /// This function requires SDL mixer to have been initialized with a successful call to `init`, but does not need an actual Mixer to have been created.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn init(
        path: [*:0]const u8,
        props: ?properties.Group,
    ) !AudioDecoder {
        return .{
            .value = try errors.wrapCallNull(*c.MIX_AudioDecoder, c.MIX_CreateAudioDecoder(path, if (props) |val| val.value else 0)),
        };
    }

    /// Create an audio decoder from an IO stream.
    ///
    /// ## Function Parameters
    /// * `io`: The i/o stream from which to load data.
    /// * `close_io`: If true, close the i/o stream when done with it.
    /// * `props`: Decoder-specific properties if desired.
    ///
    /// ## Return Value
    /// Returns an audio decoder, ready to decode.
    ///
    /// ## Remarks
    /// Most apps won't need this, as SDL mixer's usual interfaces will decode audio as needed.
    /// However, if one wants to decode an audio file into a memory buffer without playing it, this interface offers that.
    ///
    /// This function allows properties to be specified.
    /// This is intended to supply file-specific settings, such as where to find SoundFonts for a MIDI file, etc.
    /// In most cases, the caller should pass null to specify no extra properties.
    ///
    /// If `close_io` is true, then io will be closed when this decoder is done with it.
    /// If this function fails and closeio is true, then io will be closed before this function returns.
    ///
    /// When done with the audio decoder, it can be destroyed with `AudioDecoder.deinit`
    ///
    /// This function requires SDL mixer to have been initialized with a successful call to `init`, but does not need an actual Mixer to have been created.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn initIo(
        io: io_stream.Stream,
        close_io: bool,
        props: ?properties.Group,
    ) !AudioDecoder {
        return .{
            .value = try errors.wrapCallNull(*c.MIX_AudioDecoder, c.MIX_CreateAudioDecoder_IO(io.value, close_io, if (props) |val| val.value else 0)),
        };
    }
};

/// The duration of an audio track.
pub const AudioDuration = union(enum) {
    /// Audio duration in frames.
    frames: usize,
    /// The duration of the audio is infinite.
    infinite: void,
};

/// An opaque object that represents a grouping of tracks.
///
/// ## Remarks
/// SDL mixer offers callbacks at various stages of the mixing pipeline to allow apps to view and manipulate data as it is transformed.
/// Sometimes it is useful to hook in at a point where several tracks--but not all tracks-- have been mixed.
/// For example, when a game is in some options menu, perhaps adjusting game audio but not UI sounds could be useful.
///
/// SDL mixer allows you to assign several tracks to a group, and receive a callback when that group has finished mixing,
/// with a buffer of just that group's mixed audio, before it mixes into the final output.
///
/// ## Version
/// This datatype is available since SDL_mixer 3.0.0.
pub const Group = struct {
    value: *c.MIX_Group,

    /// Destroy a mixing group.
    ///
    /// ## Function Parameters
    /// * `self`: The group to destroy.
    ///
    /// ## Remarks
    /// Any tracks currently assigned to this group will be reassigned to the mixer's internal default group.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
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

    /// Get the mixer that owns a group.
    ///
    /// ## Function Parameters
    /// * `self`: The group to query.
    ///
    /// ## Return Value
    /// Returns the mixer associated with the group.
    ///
    /// ## Remarks
    /// This is the mixer pointer that was passed to `Group.init`.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn getMixer(
        self: Group,
    ) !Mixer {
        return .{ .value = try errors.wrapCallNull(*c.MIX_Mixer, c.MIX_GetGroupMixer(self.value)) };
    }

    /// Create a mixing group.
    ///
    /// ## Function Parameters
    /// * `mixer`: The mixer on which to create a mixing group.
    ///
    /// ## Return Value
    /// Returns a new `Group`. The caller must call `deinit()` on it when done.
    ///
    /// ## Remarks
    /// Tracks are assigned to a mixing group (or if unassigned, they live in a mixer's internal default group).
    /// All tracks in a group are mixed together and the app can access this mixed data before it is mixed with all other groups to produce the final output.
    ///
    /// This can be a useful feature, but is completely optional; apps can ignore mixing groups entirely and still have a full experience with SDL mixer.
    ///
    /// After creating a group, assign tracks to it with `Track.setGroup`. Use `Group.setPostMixCallback` to access the group's mixed data.
    ///
    /// A mixing group can be destroyed with `Group.deinit` when no longer needed.
    /// Destroying the mixer will also destroy all its still-existing mixing groups.
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

    /// Set a callback that fires when a mixer group has completed mixing.
    ///
    /// ## Function Parameters
    /// * `self`: The mixing group to assign this callback to.
    /// * `UserData`: Type of user data for the callback.
    /// * `callback`: The function to call when the group mixes or `null` to clear.
    /// * `user_data`: The user data to pass to the callback.
    ///
    /// ## Remarks
    /// After all playing tracks in a mixer group have pulled in more data from their inputs, transformed it, and mixed together into a single buffer,
    /// a callback can be fired. This lets an app view the data at the last moment that it is still a part of this group.
    /// It can also change the data in any way it pleases during this callback, and the mixer will continue as if this data came directly from the group's mix buffer.
    ///
    /// Each group has its own unique callback.
    /// Tracks that aren't in an explicit `Group` are mixed in an internal grouping that is not available to the app.
    ///
    /// Passing a `null` callback here is legal; it disables this group's callback.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn setGroupPostCallback(
        self: Group,
        comptime UserData: type,
        comptime callback: ?GroupMixCallback(UserData),
        user_data: ?*UserData,
    ) !void {
        const Cb = struct {
            pub fn run(
                user_data_c: ?*anyopaque,
                group_c: [*c]c.MIX_Group,
                spec_c: [*c]c.SDL_AudioSpec,
                pcm_c: [*c]f32,
                samples_c: c_int,
            ) callconv(.c) void {
                return callback(
                    @ptrCast(@alignCast(user_data_c)),
                    .{ .value = group_c },
                    audio.Spec.fromSdl(spec_c.*),
                    pcm_c[0..@intCast(samples_c)],
                );
            }
        };
        return errors.wrapCallBool(c.MIX_SetGroupPostMixCallback(self.value, if (callback != null) Cb.run else null, @ptrCast(@alignCast(user_data))));
    }
};

/// An opaque object that represents a mixer.
///
/// ## Remarks
/// The MIX mixer is the toplevel object for this library.
/// To use SDL mixer, you must have at least one, but are allowed to have several.
/// Each mixer is responsible for generating a single output stream of mixed audio, usually to an audio device for realtime playback.
///
/// Mixers are either created to feed an audio device (through `Mixer.initDevice`), or to generate audio to a buffer in memory, where it can be used for anything (through `Mixer.init`).
///
/// ## Version
/// This datatype is available since SDL_mixer 3.0.0.
pub const Mixer = struct {
    value: *c.MIX_Mixer,

    /// Free a mixer.
    ///
    /// ## Function Parameters
    /// * `self`: The mixer to destroy.
    ///
    /// ## Remarks
    /// If this mixer was created with `Mixer.initDevice`, this function will also close the audio device and call `sdl3.quit(.{ .audio = true })`.
    ///
    /// Any `Group` or `Track` created for this mixer will also be destroyed.
    /// Do not access them again or attempt to destroy them after the device is destroyed.
    /// `Audio` objects will not be destroyed, since they can be shared between mixers (but those will all be destroyed during `quit`).
    ///
    /// ## Thread Safety
    /// If this is used with a `Mixer` from `Mixer.initDevice`, then this function should only be called on the main thread.
    /// If this is used with a `Mixer` from `Mixer.init`, then it is safe to call this function from any thread.
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

    /// Generate mixer output when not driving an audio device.
    ///
    /// ## Function Parameters
    /// * `self`: The mixer for which to generate more audio.
    /// * `buffer`: The buffer to store audio in.
    ///
    /// ## Return Value
    /// Returns the portion of the buffer containing actually mixed audio.
    ///
    /// ## Remarks
    /// SDL mixer allows the creation of MIX Mixer objects that are not connected to an audio device, by calling `Mixer.init` instead of `Mixer.initDevice`.
    /// Such mixers will not generate output until explicitly requested through this function.
    ///
    /// The caller may request as much audio as desired, so long as buflen is a multiple of the sample frame size specified when creating the mixer
    /// (for example, if requesting stereo Sint16 audio, buflen must be a multiple of 4: 2 bytes-per-channel times 2 channels).
    ///
    /// The mixer will mix as quickly as possible; since it works in sample frames instead of time, it can potentially generate enormous amounts of audio in a small amount of time.
    ///
    /// On success, this always fills buffer with buflen bytes of audio; if all playing tracks finish mixing, it will fill the remaining buffer with silence.
    ///
    /// Each call to this function will pick up where it left off, playing tracks will continue to mix from the point the previous call completed, etc.
    /// The mixer state can be changed between each call in any way desired: tracks can be added, played, stopped, changed, removed, etc.
    /// Effectively this function does the same thing SDL mixer does internally when the audio device needs more audio to play.
    ///
    /// This function can not be used with mixers from `Mixer.initDevice` those generate audio as needed internally.
    ///
    /// This function returns the number of the buffe of real audio mixed, which might be less than `buffer.len`.
    /// While all buffer bytes of buffer will be initialized, if available tracks to mix run out, the end of the buffer will be initialized with silence;
    /// this silence will not be counted in the return value, so the caller has the option to identify how much of the buffer has legimitate contents vs appended silence.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn generate(
        self: Mixer,
        buffer: []u8,
    ) ![]u8 {
        const len: usize = @intCast(try errors.wrapCall(c_int, c.MIX_Generate(
            self.value,
            buffer.ptr,
            @intCast(buffer.len),
        ), -1));
        return buffer[0..len];
    }

    /// Get the audio format a mixer is generating.
    ///
    /// ## Function Parameters
    /// * `self`: The mixer to query.
    ///
    /// ## Return Value
    /// Returns the audio specification of the mixer.
    ///
    /// ## Remarks
    /// Generally you don't need this information, as SDL mixer will convert data as necessary between inputs you provide and its output format,
    /// but it might be useful if trying to match your inputs to reduce conversion and resampling costs.
    ///
    /// For mixers created with `Mixer.initDevice`, this is the format of the audio device (and may change later if the device itself changes;
    /// SDL_mixer will seamlessly handle this change internally, though).
    ///
    /// For mixers created with `Mixer.init`, this is the format that `Mixer.generate` will produce, as requested at create time, and does not change.
    ///
    /// Note that internally, SDL mixer will work in `floating_32_bit` format before outputting the format specified here,
    /// so it would be more efficient to match input data to that, not the final output format.
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

    /// Get a mixer's master frequency ratio.
    ///
    /// ## Function Parameters
    /// * `self`: The mixer to query.
    ///
    /// ## Return Value
    /// Returns the mixer's current master frequency ratio.
    ///
    /// ## Remarks
    /// This returns the last value set through `Mixer.setFrequencyRatio`, or `1` if no value has ever been explicitly set.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn getFrequencyRatio(
        self: Mixer,
    ) f32 {
        return c.MIX_GetMixerFrequencyRatio(self.value);
    }

    /// Get a mixer's master gain control.
    ///
    /// ## Function Parameters
    /// * `self`: The mixer to query.
    ///
    /// ## Return Value
    /// Returns the current master gain.
    ///
    /// ## Remarks
    /// This returns the last value set through `Mixer.setGain` or `1` if no value has ever been explicitly set.
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

    /// Get all tracks with a specific tag.
    ///
    /// ## Function Parameters
    /// * `self`: The mixer to query.
    /// * `tag`: The tag to search.
    ///
    /// ## Return Value
    /// Returns an array of the tracks.
    /// The returned slice should be freed with `sdl3.free` when it is no longer needed.
    ///
    /// ## Remarks
    /// Tracks are not provided in any guaranteed order.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn getTaggedTracks(
        self: Mixer,
        tag: [:0]const u8,
    ) ![]Track {
        var num: c_int = undefined;
        const ret = try errors.wrapCallNull([*]Track, @ptrCast(@alignCast(c.MIX_GetTaggedTracks(self.value, tag, &num))));
        return ret[0..@intCast(num)];
    }

    /// Create a mixer that generates audio to a memory buffer.
    ///
    /// ## Function Parameters
    /// * `spec`: The audio format that mixer will generate.
    ///
    /// ## Return Value
    /// Returns a mixer that can be used to generate audio.
    ///
    /// ## Remarks
    /// Usually you want `Mixer.initDevice` instead of this function.
    /// The mixer created here can be used with `Mixer.generate` to produce more data on demand, as fast as desired.
    ///
    /// An audio format must be specified.
    /// This is the format it will output in.
    ///
    /// Once a mixer is created, next steps are usually to load audio (through `Mixer.loadAudio` and friends), create a track (`Mixer.createTrack`), and play that audio through that track.
    ///
    /// When done with the mixer, it can be destroyed with `Mixer.deinit`.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn init(
        spec: audio.Spec,
    ) !Mixer {
        return Mixer{ .value = try errors.wrapCallNull(*c.MIX_Mixer, c.MIX_CreateMixer(&spec.toSdl())) };
    }

    /// Create a mixer that plays sound directly to an audio device.
    ///
    /// ## Function Parameters
    /// * `device`: The audio device to open, such as `audio.Device.default_playback`.
    /// * `spec`: The audio format to mix in, or `null` to let SDL_mixer choose a reasonable default.
    ///
    /// ## Return Value
    /// Returns a new `mixer.Mixer`.
    ///
    /// ## Remarks
    /// This is usually the function you want, vs `Mixer.init`.
    ///
    /// You can choose a specific device ID to open, following SDL's usual rules, but often the correct choice is to specify `audio.Device.default_playback`
    /// and let SDL figure out what device to use (and seamlessly transition you to new hardware if the default changes).
    ///
    /// Only playback devices make sense here. Attempting to open a recording device will fail.
    ///
    /// This will call `sdl3.init(.{ .audio = true })` internally; it's safe to call `sdl3.init` before this call, too, if you intend to enumerate audio devices to choose one to open here.
    ///
    /// An audio format can be requested, and the system will try to set the hardware to those specifications, or as close as possible, but this is just a hint.
    /// SDL mixer will handle all data conversion behind the scenes in any case, and specifying a `null` spec is a reasonable choice.
    /// The best reason to specify a format is because you know all your data is in that format and it might save some unnecessary CPU time on conversion.
    ///
    /// The actual device format chosen is available through `Mixer.getFormat`.
    ///
    /// Once a mixer is created, next steps are usually to load audio (through `Mixer.loadAudio` and friends), create a track (`Mixer.Track.init`), and play that audio through that track.
    ///
    /// When done with the mixer, it can be destroyed with `Mixer.deinit`.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn initDevice(
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
};

/// 3D coordinates for `track.set3dPosition`.
///
/// ## Remarks
/// The coordinates use a "right-handed" coordinate system, like OpenGL and OpenAL.
///
/// ## Version
/// This struct is available since SDL_mixer 3.0.0.
pub const Point3d = extern struct {
    /// X coordinate (negative left, positive right).
    x: f32,
    /// Y coordinate (negative down, positive up).
    y: f32,
    /// Z coordinate (negative forward, positive back).
    z: f32,

    comptime {
        errors.assertStructsEqual(@This(), c.MIX_Point3D);
    }

    /// Convert from an SDL value.
    pub fn fromSdl(
        value: c.MIX_Point3D,
    ) Point3d {
        return .{
            .x = value.x,
            .y = value.y,
            .z = value.z,
        };
    }

    /// Convert to an SDL value.
    pub fn toSdl(
        self: Point3d,
    ) c.MIX_Point3D {
        return .{
            .x = self.x,
            .y = self.y,
            .z = self.z,
        };
    }
};

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

/// A set of per-channel gains for tracks using `track.setStereo`.
///
/// ## Remarks
/// When forcing a track to stereo, the app can specify a per-channel gain, to further adjust the left or right outputs.
/// When mixing audio that has been forced to stereo, each channel is modulated by these values. A value of `1` produces no change, `0` produces silence.
/// A simple panning effect would be to set left to the desired value and right to `1 - left`.
///
/// ## Version
/// This struct is available since SDL_mixer 3.0.0.
pub const StereoGains = extern struct {
    /// Left channel gain.
    left: f32,
    /// Right channel gain.
    right: f32,

    comptime {
        errors.assertStructsEqual(@This(), c.MIX_StereoGains);
    }
};

/// An opaque object that represents a source of sound output to be mixed.
///
/// ## Remarks
/// A MIX Mixer has an arbitrary number of tracks, and each track manages its own unique audio to be mixed together.
///
/// Tracks also have other properties: gain, loop points, fading, 3D position, and other attributes that alter the produced sound; many can be altered during playback.
///
/// ## Version
/// This datatype is available since SDL_mixer 3.0.0.
pub const Track = struct {
    value: *c.MIX_Track,

    /// Destroy the specified track.
    ///
    /// ## Function Parameters
    /// * `self`: The track to destroy.
    ///
    /// ## Remarks
    /// If the track is currently playing, it will be stopped immediately, without any fadeout.
    /// If there is a callback set through `Track.setStoppedCallback`, it will not be called.
    ///
    /// If the mixer is currently mixing in another thread, this will block until it finishes.
    /// Destroying a track from the mixer thread itself (during a callback) will cause it to be destroyed as soon as this iteration of the mixer thread is not using it;
    /// in this scenario, destroying a track and then making futher changes to it is considered undefined behavior.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
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

    /// Create a new track on a mixer.
    ///
    /// ## Function Parameters
    /// * `mixer`: The mixer to create the track on.
    ///
    /// ## Return Value
    /// Returns a new `mixer.Track`. The caller must call `deinit()` on it when done.
    ///
    /// ## Remarks
    /// A track provides a single source of audio.
    /// All currently-playing tracks will be processed and mixed together to form the final output from the mixer.
    ///
    /// There are no limits to the number of tracks one may create, beyond running out of memory,
    /// but in normal practice there are a small number of tracks that are reused between all loaded audio as appropriate.
    ///
    /// Tracks are unique to a specific `Mixer` and can't be transferred between them.
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

    /// Get a track's current position in 3D space.
    ///
    /// ## Function Parameters
    /// * `self`: The track to query.
    ///
    /// ## Return Value
    /// The track's position.
    ///
    /// ## Remarks
    /// If 3D positioning isn't enabled for this track, through a call to `Track.set3dPosition`, this will return the zero vector.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn get3dPosition(
        self: Track,
    ) !Point3d {
        var ret: c.MIX_Point3D = undefined;
        try errors.wrapCallBool(c.MIX_GetTrack3DPosition(self.value, &ret));
        return .fromSdl(ret);
    }

    /// Query the audio assigned to a track.
    ///
    /// ## Function Parameters
    /// * `self`: The track to query.
    ///
    /// ## Return Value
    /// Returns the audio if available.
    ///
    /// ## Remarks
    /// This returns the `Audio` object currently assigned to track through a call to `Track.setAudio`.
    /// If there is none assigned, or the track has an input that isn't an `Audio` (such as an `sdl3.audio.Stream` or `sdl3.io_stream.Stream`), this will return `null`.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn getAudio(
        self: Track,
    ) ?Audio {
        const ret = c.MIX_GetTrackAudio(self.value);
        if (ret) |val|
            return .{ .value = val };
        return null;
    }

    /// Query the audio stream assigned to a track.
    ///
    /// ## Function Parameters
    /// * `self`: The track to query.
    ///
    /// ## Return Value
    /// Returns the audio stream if available.
    ///
    /// ## Remarks
    /// This returns the audio stream object currently assigned to track through a call to `Track.setAudioStream`.
    /// If there is none assigned, or the track has an input that isn't an SDL_AudioStream (such as a `Audio` or `sdl3.io_stream.Stream`), this will return `null`.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn getAudioStream(
        self: Track,
    ) ?audio.Stream {
        const ret = c.MIX_GetTrackAudioStream(self.value);
        if (ret) |val|
            return .{ .value = val };
        return null;
    }

    /// Query whether a given track is fading.
    ///
    /// ## Function Parameters
    /// * `self`: The track to query.
    ///
    /// ## Return Value
    /// Returns less than `0` if the track is fading out, greater than `0` if fading in, `0` otherwise.
    ///
    /// ## Remarks
    /// This specifically checks if the track is not stopped (paused or playing), and it is fading in or out, and returns the number of frames remaining in the fade.
    ///
    /// If fading out, the returned value will be negative.
    /// When fading in, the returned value will be positive.
    /// If not fading, this function returns zero.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn getFadeFrames(
        self: Track,
    ) isize {
        return @intCast(c.MIX_GetTrackFadeFrames(self.value));
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

    /// Assign a track to a mixing group.
    ///
    /// ## Function Parameters
    /// * `self`: The track to set mixing group assignment.
    /// * `group`: The group to assign the track to, or `null` to remove it from any group.
    ///
    /// ## Remarks
    /// All tracks in a group are mixed together, and that output is made available to the app before it is mixed into the final output.
    ///
    /// Tracks can only be in one group at a time, and the track and group must have been created on the same `Mixer`.
    ///
    /// Setting a track to a `null` group will remove it from any app-created groups, and reassign it to the mixer's internal default group.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn setGroup(
        self: Track,
        group: ?Group,
    ) !void {
        const ret = c.MIX_SetTrackGroup(
            self.value,
            if (group) |val| val.value else null,
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

/// SDL mixer version information.
pub const Version = struct {
    value: c_int,

    /// SDL mixer version compiled against.
    ///
    /// ## Version
    /// This constant is available since SDL mixer 3.0.0.
    pub const compiled_against = Version{ .value = c.SDL_MIXER_VERSION };

    /// Check if the SDL mixer version is at least greater than the given one.
    ///
    /// ## Function Parameters
    /// * `major`: The major version number.
    /// * `minor`: The minor version number.
    /// * `micro`: The micro version number.
    ///
    /// ## Return Value
    /// Returns if the mixer version is at least this given version.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn atLeast(
        major: u32,
        minor: u32,
        micro: u32,
    ) bool {
        const ret = c.SDL_MIXER_VERSION_ATLEAST(
            major,
            minor,
            micro,
        );
        return ret;
    }

    /// Create an SDL mixer version number.
    ///
    /// ## Function Parameters
    /// * `major`: The major version number.
    /// * `minor`: The minor version number.
    /// * `micro`: The micro version number.
    ///
    /// ## Return Value
    /// Returns the new version number.
    pub fn make(
        major: u32,
        minor: u32,
        micro: u32,
    ) Version {
        const ret = c.SDL_VERSIONNUM(
            @as(c_int, @intCast(major)),
            @as(c_int, @intCast(minor)),
            @as(c_int, @intCast(micro)),
        );
        return Version{ .value = ret };
    }

    /// Get the version of SDL mixer that is linked against your program.
    /// Possibly different than the compiled against version.
    ///
    /// ## Remarks
    /// If you are linking to SDL_mixer dynamically, then it is possible that the current version will be different than the version you compiled against.
    /// This function returns the current version, while `compiled_against` is the version you compiled with.
    ///
    /// This function may be called safely at any time, even before `init`.
    ///
    /// ## Return Value
    /// Returns the version compiled against mixer.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn get() Version {
        const ret = c.MIX_Version();
        return Version{ .value = ret };
    }

    /// Major version number.
    ///
    /// ## Function Parameters
    /// * `self`: The version.
    ///
    /// ## Return Value
    /// The major version number.
    pub fn getMajor(
        self: Version,
    ) u32 {
        const ret = c.SDL_VERSIONNUM_MAJOR(
            self.value,
        );
        return @intCast(ret);
    }

    /// Micro version number.
    ///
    /// ## Function Parameters
    /// * `self`: The version.
    ///
    /// ## Return Value
    /// The micro version number.
    pub fn getMicro(
        self: Version,
    ) u32 {
        const ret = c.SDL_VERSIONNUM_MICRO(
            self.value,
        );
        return @intCast(ret);
    }

    /// Minor version number.
    ///
    /// ## Function Parameters
    /// * `self`: The version.
    ///
    /// ## Return Value
    /// The minor version number.
    pub fn getMinor(
        self: Version,
    ) u32 {
        const ret = c.SDL_VERSIONNUM_MINOR(
            self.value,
        );
        return @intCast(ret);
    }
};

/// Convert sample frames, at a specific sample rate, to milliseconds.
///
/// ## Function Parameters
/// * `sample_rate`: The sample rate to use for conversion.
/// * `frames`: The rate-specific sample frames to convert to milliseconds.
///
/// ## Return Value
/// Returns converted number of milliseconds.
///
/// ## Remarks
/// Sample frames are more precise than milliseconds, so out of necessity, this function will approximate by rounding down to the closest full millisecond.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// Version
/// This function is available since SDL_mixer 3.0.0.
pub fn framesToMs(
    sample_rate: u32,
    frames: usize,
) !usize {
    return @intCast(try errors.wrapCall(c.Sint64, c.MIX_FramesToMS(@intCast(sample_rate), @intCast(frames)), -1));
}

/// Report the name of a specific audio decoders.
///
/// ## Function Parameters
/// * `index`: The index of the decoder to query.
///
/// ## Return Value
/// Returns a UTF-8 (really, ASCII) string of the decoder's name.
///
/// ## Remarks
/// An audio decoder is what turns specific audio file formats into usable PCM data.
/// For example, there might be an MP3 decoder, or a WAV decoder, etc. SDL mixer probably has several decoders built in.
///
/// The names are capital English letters and numbers, low-ASCII.
/// They don't necessarily map to a specific file format; Some decoders, like "XMP" operate on multiple file types, and more than one decoder might handle the same file type,
/// like "DRMP3" vs "MPG123". Note that in that last example, neither decoder is called "MP3".
///
/// The index of a specific decoder is decided during `init` and does not change until the library is deinitialized.
/// Valid indices are between zero and the return value of `getNumAudioDecoders`.
///
/// The returned pointer is const memory owned by SDL mixer; do not free it.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL_mixer 3.0.0.
pub fn getAudioDecoder(
    index: usize,
) ![:0]const u8 {
    return errors.wrapCallCString(c.MIX_GetAudioDecoder(@intCast(index)));
}

/// Report the number of audio decoders available for use.
///
/// ## Return Value
/// Returns the number of decoders available.
///
/// ## Remarks
/// An audio decoder is what turns specific audio file formats into usable PCM data.
/// For example, there might be an MP3 decoder, or a WAV decoder, etc. SDL mixer probably has several decoders built in.
///
/// The return value can be used to call `getAudioDecoder` in a loop.
///
/// The number of decoders available is decided during `init` and does not change until the library is deinitialized.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL_mixer 3.0.0.
pub fn getNumAudioDecoders() usize {
    return @intCast(c.MIX_GetNumAudioDecoders());
}

/// Initialize the SDL mixer library.
///
/// ## Remarks
/// This must be successfully called once before (almost) any other SDL_mixer function can be used.
/// It is safe to call this multiple times; the library will only initialize once, and won't deinitialize until `mixer.quit()` has been called a matching number of times.
/// Extra attempts to init report success.
///
/// ## Thread Safety
/// This function is not thread safe.
///
/// ## Version
/// This function is available since SDL_mixer 3.0.0.
pub fn init() !void {
    const ret = c.MIX_Init();
    return errors.wrapCallBool(ret);
}

/// Deinitialize the SDL mixer library.
///
/// ## Remarks
/// This must be called when done with the library, probably at the end of your program.
///
/// It is safe to call this multiple times; the library will only deinitialize once, when this function is called the same number of times as `init` was successfully called.
///
/// Once you have successfully deinitialized the library, it is safe to call `init` to reinitialize it for further use.
///
/// On successful deinitialization, SDL mixer will destroy almost all created objects, including objects of type:
/// * Mixer
/// * Track
/// * Audio
/// * Group
/// * AudioDecoder
/// ...which is to say: it's possible a single call to this function will clean up anything it allocated, stop all audio output, close audio devices, etc.
/// Don't attempt to destroy objects after this call.
/// The app is still encouraged to manage their resources carefully and clean up first, treating this function as a safety net against memory leaks.
///
/// ## Thread Safety
/// This function is not thread safe.
///
/// ## Version
/// This function is available since SDL_mixer 3.0.0.
pub fn quit() void {
    c.MIX_Quit();
}

test "mixer" {
    errors.refAllDeclsRecursive(@This());
}
