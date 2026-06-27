const c = @import("c");
const errors = @import("errors.zig");
const std = @import("std");

comptime {
    if (!@hasDecl(c, "NET_Quit"))
        @compileError("The ext_net feature is either not enabled or not working!");
}

/// Opaque representation of a computer-readable network address.
///
/// ## Remarks
/// This is an opaque datatype, to be treated by the app as a handle.
///
/// SDL_net uses these to identify other servers; you use them to connect to a remote machine, and you use them to find out who connected to you.
/// They are also used to decide what network interface to use when creating a server.
///
/// These are intended to be protocol-independent; a given address might be for IPv4, IPv6, or something more esoteric.
/// SDL net attempts to hide the differences.
///
/// ## Version
/// This datatype is available since SDL_net 3.0.0.
pub const Address = extern struct {
    value: *c.NET_Address,

    comptime {
        std.debug.assert(@sizeOf(Address) == @sizeOf(*c.NET_Address));
    }

    /// Compare two `Address` objects.
    ///
    /// ## Function Parameters
    /// * `self`: The first address to compare.
    /// * `other`: second address to compare.
    ///
    /// ## Return Value
    /// Returns `std.math.Order.lt` if `self` is "less than" `other`, `std.math.Order.gt` if "greater than", `std.math.Order.eq` if equal.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn compare(
        self: Address,
        other: Address,
    ) std.math.Order {
        return std.math.order(c.NET_CompareAddresses(self.value, other.value), 0);
    }

    /// Drop a reference to an `net.Address`.
    ///
    /// ## Function Parameters
    /// * `self`: The address to deinitialize.
    ///
    /// ## Remarks
    /// Since several pieces of the library might share a single `net.Address`, including a background thread that's working on resolving, these objects are referenced counted.
    /// This allows everything that's using it to declare they still want it, and drop their reference to the address when they are done with it.
    /// The object's resources are freed when the last reference is dropped.
    /// This function drops a reference to an `net.Address`, decreasing its reference count by one.
    /// The documentation will tell you when the app has to explicitly unref an address.
    /// For example, `net.Address.init()` creates addresses that are already referenced, so the caller needs to call `deinit()` when done.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn deinit(
        self: Address,
    ) void {
        c.NET_UnrefAddress(self.value);
    }

    /// Check if an address is resolved, without blocking.
    ///
    /// ## Function Parameters
    /// * `self`: The address to query.
    ///
    /// ## Return Value
    /// Returns `net.Address.Status.resolved` if successfully resolved, `net.Address.Status.resolving` if still resolving.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn getStatus(
        self: Address,
    ) Error!Status {
        return Status.fromSdl(c.NET_GetAddressStatus(self.value));
    }

    /// Get a human-readable string from a resolved address.
    ///
    /// ## Function Parameters
    /// * `self`: The address to query.
    ///
    /// ## Return Value
    /// Returns a string, or `null` on error or if not yet resolved.
    ///
    /// ## Remarks
    /// The returned string is owned by the `net.Address` and is valid as long as the object lives.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn getString(
        self: Address,
    ) ?[:0]const u8 {
        const ret = c.NET_GetAddressString(self.value);
        if (ret == null) return null;
        return std.mem.sliceTo(ret, 0);
    }

    /// Resolve a human-readable hostname.
    ///
    /// ## Function Parameters
    /// * `host`: The hostname to resolve.
    ///
    /// ## Return Value
    /// Returns a new address on success.
    ///
    /// ## Remarks
    /// SDL_net doesn't operate on human-readable hostnames (like `www.libsdl.org`) but on computer-readable addresses.
    /// This function converts from one to the other. This process is known as "resolving" an address.
    /// You can also use this to turn IP address strings (like "159.203.69.7") into `net.Address` objects.
    /// Note that resolving an address is an asynchronous operation, since the library will need to ask a server on the internet to get the information it needs, and this can take time (and possibly fail later).
    /// This function will not block. It either returns an error (catastrophic failure) or an unresolved `net.Address`.
    /// Until the address resolves, it can't be used.
    /// If you want to block until the resolution is finished, you can call `net.Address.waitUntilResolved()`.
    /// Otherwise, you can do a non-blocking check with `net.Address.getStatus()`.
    /// When you are done with the returned `net.Address`, call `deinit()` to dispose of it.
    /// You need to do this even if resolution later fails asynchronously.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn init(
        host: [:0]const u8,
    ) Error!Address {
        return .{
            .value = try errors.wrapCallNull(*c.NET_Address, c.NET_ResolveHostname(host.ptr)),
        };
    }

    /// Add a reference to an `net.Address`.
    ///
    /// ## Function Parameters
    /// * `self`: The address to add a reference to.
    ///
    /// ## Return Value
    /// Returns the same address that was passed as a parameter.
    ///
    /// ## Remarks
    /// Since several pieces of the library might share a single `net.Address`, these objects are referenced counted.
    /// This function adds a reference to an `net.Address`, increasing its reference count by one.
    /// Generally you only have to explicit ref an address when you have different parts of your own app that will be sharing an address.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn ref(
        self: Address,
    ) !Address {
        return .{ .value = try errors.wrapCallNull(*c.NET_Address, c.NET_RefAddress(self.value)) };
    }

    /// Block until an address is resolved.
    ///
    /// ## Function Parameters
    /// * `self`: The address object to wait on.
    /// * `timeout`: The maximum time to wait for resolution to complete.
    ///
    /// ## Return Value
    /// Returns `true` if successfully resolved, `false` if the timeout was reached.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread, and several threads can block on the same address simultaneously.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn waitUntilResolved(
        self: Address,
        timeout: Timeout,
    ) Error!bool {
        const ret = c.NET_WaitUntilResolved(self.value, timeout.toSdl());
        if (ret < 0) {
            errors.callErrorCallback();
            return error.SdlNetError;
        }
        return ret == 1;
    }
};

/// The data provided for new incoming packets from `DatagramSocket.receive`.
///
/// ## Version
/// This datatype is available since SDL_net 3.0.0.
pub const Datagram = extern struct {
    /// Sender's address. This is unref'd by `Datagram.deinit`.
    /// You only need to ref it if you want to keep it.
    addr: Address,
    /// Sender's port.
    /// These do not have to come from the same port the receiver is bound to.
    /// These are in host byte order, don't byteswap them!
    port: u16,
    /// The payload of this datagram.
    buf: [*]u8,
    /// The number of bytes available at `buf`.
    buf_len: c_int,

    comptime {
        errors.assertStructsEqual(@This(), c.NET_Datagram);
    }

    /// Dispose of a datagram packet previously received.
    ///
    /// ## Function Parameters
    /// * `self`: The datagram to destroy.
    ///
    /// ## Remarks
    /// You must pass packets received through `ReceiveDatagram` to this function when you are done with them.
    /// This will free resources used by this packet and unref its `Address`.
    ///
    /// If you want to save the sender's address from the packet past this time, it is safe to call `Address.ref` on the address and hold onto its pointer,
    /// so long as you call `Address.unref` on it when you are done with it.
    ///
    /// Once you call this function, the datagram pointer becomes invalid and should not be used again by the app.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn deinit(
        self: *Datagram,
    ) void {
        c.NET_DestroyDatagram(@ptrCast(@alignCast(self)));
    }

    /// Get the data payload of the datagram.
    ///
    /// ## Function Parameters
    /// * `self`: The datagram to get the data from.
    ///
    /// ## Remarks
    /// The returned slice is owned by the datagram and is valid until `deinit()` is called.
    ///
    /// ## Version
    /// This function is provided by zig-sdl3.
    pub fn getData(
        self: Datagram,
    ) []const u8 {
        return self.buf[0..@intCast(self.buf_len)];
    }
};

/// An object that represents a datagram connection to another system.
///
/// ## Remarks
/// This is meant to be an unreliable, packet-oriented connection, such as UDP.
///
/// Datagram sockets follow different rules than stream sockets.
/// They are not a reliable stream of bytes but rather packets, they are not limited to talking to a single other remote system,
/// they do not maintain a single "connection" that can be dropped, and they are more nimble about network failures at the expense of being more complex to use.
/// What makes sense for your app depends entirely on what your app is trying to accomplish.
///
/// Generally the idea of a datagram socket is that you send data one chunk ("packet") at a time to any address you want,
/// and it arrives whenever it gets there, even if later packets get there first, and maybe it doesn't get there at all, and you don't know when anything of this happens by default.
///
/// ## Version
/// This datatype is available since SDL_net 3.0.0.
pub const DatagramSocket = struct {
    value: *c.NET_DatagramSocket,

    /// Dispose of a previously-created datagram socket.
    ///
    /// ## Function Parameters
    /// * `self`: The datagram socket to destroy.
    ///
    /// ## Remarks
    /// This will abandon any data queued for sending that hasn't made it to the socket.
    /// If you need this data to arrive, you should wait for confirmation from the remote computer in some form that you devise yourself.
    /// Queued data is not guaranteed to arrive even if the library made efforts to transmit it here.
    ///
    /// Any data that has arrived from the remote end of the connection that hasn't been read yet is lost.
    ///
    /// ## Thread Safety
    /// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
    /// However, different threads may access different sockets at the same time without problems.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn deinit(
        self: DatagramSocket,
    ) void {
        c.NET_DestroyDatagramSocket(self.value);
    }

    /// Create and bind a new datagram socket.
    ///
    /// ## Function Parameters
    /// * `addr`: the local address to listen for connections on, or `null` to listen on all available local addresses.
    /// * `port`: the port on the local address to listen for connections on, or zero for the system to decide.
    ///
    /// ## Return Value
    /// Returns a new `net.DatagramSocket`.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn init(
        addr: ?Address,
        port: u16,
    ) Error!DatagramSocket {
        const addr_ptr = if (addr) |a| a.value else null;
        return .{
            .value = try errors.wrapCallNull(*c.NET_DatagramSocket, c.NET_CreateDatagramSocket(addr_ptr, port, 0)),
        };
    }

    /// Receive a new packet that a remote system sent to a datagram socket.
    ///
    /// ## Function Parameters
    /// * `self`: The datagram socket to receive data from.
    ///
    /// ## Return Value
    /// Returns a new datagram packet if one was available, `null` otherwise.
    /// The caller must call `Datagram.deinit` on the returned datagram when done with it.
    ///
    /// ## Remarks
    /// Datagram sockets send packets of data.
    /// They either arrive as complete packets or they don't arrive at all, so you'll never receive half a packet.
    ///
    /// This call never blocks; if no new data is available at the time of the call, it returns immediately.
    /// The caller can try again later.
    ///
    /// On a successful call to this function, it returns, even if no new packets are available.
    ///
    /// You must pass received packets to `Datagram.deinit` when you are done with them.
    /// If you want to save the sender's address past this time, it is safe to call `Address.ref` on the address and hold onto the pointer,
    /// so long as you call `Address.unref` on it when you are done with it.
    ///
    /// Since datagrams can arrive from any address or port on the network without prior warning,
    /// this information is available in the `Datagram` object that is provided by this function, and this is the only way to know who to reply to.
    /// Even if you aren't acting as a "server," packets can still arrive at your socket if someone sends one.
    ///
    /// If there's a fatal error, this function will error.
    /// Datagram sockets generally won't report failures, because there is no state like a "connection" to fail at this level,
    /// but may report failure for unrecoverable system-level conditions; once a datagram socket fails,
    /// you should assume it is no longer usable and should destroy it with `DatagramSocket.deinit`.
    ///
    /// ## Thread Safety
    /// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
    /// However, different threads may access different sockets at the same time without problems.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn receive(
        self: DatagramSocket,
    ) !?*Datagram {
        var ret: [*c]c.NET_Datagram = undefined;
        try errors.wrapCallBool(c.NET_ReceiveDatagram(self.value, &ret));
        if (ret == null)
            return null;
        return @ptrCast(@alignCast(ret));
    }

    /// Send a new packet over a datagram socket to a remote system.
    ///
    /// ## Function Parameters
    /// * `self`: The datagram socket to send data through.
    /// * `address`: the destination address.
    /// * `port`: the destination port.
    /// * `data`: a pointer to the data to send as a single packet.
    ///
    /// ## Thread Safety
    /// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn send(
        self: DatagramSocket,
        address: Address,
        port: u16,
        data: []const u8,
    ) Error!void {
        return errors.wrapCallBool(c.NET_SendDatagram(self.value, address.value, port, data.ptr, @intCast(data.len)));
    }

    /// Enable simulated datagram socket failures.
    ///
    /// ## Function Parameters
    /// * `self`: The datagram socket to set a failure rate on.
    /// * `percent_loss`: A number between 0 and 100. Higher means more failures. Zero to disable.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn simulatePacketLoss(
        self: DatagramSocket,
        percent_loss: u8,
    ) void {
        std.debug.assert(percent_loss <= 100);
        c.NET_SimulateDatagramPacketLoss(self.value, @intCast(percent_loss));
    }
};

/// A list of local addresses returned by `getLocalAddresses`.
///
/// ## Version
/// This struct is provided by zig-sdl3.
pub const LocalAddressList = struct {
    addresses: []Address,

    /// Free the list of local addresses.
    ///
    /// ## Function Parameters
    /// * `self`: The list to deinitialize.
    ///
    /// ## Remarks
    /// This will unref all addresses in the array and free the array itself.
    ///
    /// Since addresses are reference counted, it is safe to keep any addresses you want from this array even after calling this function,
    /// as long as you called `Address.ref` on them first.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    pub fn deinit(
        self: LocalAddressList,
    ) void {
        c.NET_FreeLocalAddresses(@ptrCast(@alignCast(self.addresses.ptr)));
    }
};

/// The receiving end of a stream connection.
///
/// ## Remarks
/// This is an opaque datatype, to be treated by the app as a handle.
///
/// Internally, this is what BSD sockets refers to as a "listen socket".
/// Clients attempt to connect to a server, and if the server accepts the connection, will provide the app with a stream socket to send and receive data over that connection.
///
/// ## Version
/// This datatype is available since SDL_net 3.0.0.
pub const Server = struct {
    value: *c.NET_Server,

    /// Dispose of a previously-created server.
    ///
    /// ## Function Parameters
    /// * `self`: The server to destroy.
    ///
    /// ## Remarks
    /// This will immediately disconnect any pending client connections that had not yet been accepted,
    /// but will not disconnect any existing accepted connections (which can still be used and must be destroyed separately).
    /// Further attempts to make new connections to this server will fail on the client side.
    ///
    /// ## Thread Safety
    /// You should not operate on the same server from multiple threads at the same time without supplying a serialization mechanism.
    /// However, different threads may access different servers at the same time without problems.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn deinit(
        self: Server,
    ) void {
        c.NET_DestroyServer(self.value);
    }

    /// Create a server, which listens for connections to accept.
    ///
    /// ## Function Parameters
    /// * `addr`: The local address to listen for connections on, or `null`.
    /// * `port`: the port on the local address to listen for connections on.
    ///
    /// ## Return Value
    /// Returns a new `net.Server`.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn init(
        addr: ?Address,
        port: u16,
    ) Error!Server {
        const addr_ptr = if (addr) |a| a.value else null;
        return .{
            .value = try errors.wrapCallNull(*c.NET_Server, c.NET_CreateServer(addr_ptr, port, 0)),
        };
    }

    /// Create a stream socket for the next pending client connection.
    ///
    /// ## Function Parameters
    /// * `self`: The server object to check for pending connections.
    ///
    /// ## Return Value
    /// Returns a new stream socket if a connection was pending, `null` otherwise.
    ///
    /// ## Remarks
    /// When a client connects to a server, their connection will be pending until the server accepts the connection.
    /// Once accepted, the server will be given a stream socket to communicate with the client, and they can send data to, and receive data from, each other.
    ///
    /// Unlike `StreamSocket.initClient`, stream sockets returned from this function are already connected and do not have to wait for the connection to complete,
    /// as server acceptance is the final step of connecting.
    ///
    /// This function does not block.
    /// In fact, this function should be called in a loop until the result is `null`, so all pending connections are accepted in a single batch.
    ///
    /// If you want the server to sleep until there's a new connection, you can use `waitUntilInputAvailable`.
    ///
    /// When done with the newly-accepted client, you can disconnect and dispose of the stream socket by calling `StreamSocket.deinit`.
    ///
    /// ## Thread Safety
    /// You should not operate on the same server from multiple threads at the same time without supplying a serialization mechanism.
    /// However, different threads may access different servers at the same time without problems.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn accept(
        self: Server,
    ) !?StreamSocket {
        var ret: ?*c.NET_StreamSocket = undefined;
        try errors.wrapCallBool(c.NET_AcceptClient(self.value, &ret));
        if (ret) |val|
            return .{ .value = val };
        return null;
    }
};

/// State for asynchronous operations.
///
/// ## Remarks
/// Lots of tasks in SDL_net are asynchronous, as they can't complete until data passes over a network at some murky future point in time.
///
/// This includes sending data over a stream socket, resolving a hostname, connecting to a remote system, and other tasks.
///
/// The library never blocks on tasks that take time to complete, with the exception of functions named "Wait", which are intended to do nothing but block until a task completes.
/// Functions that are attempting to do something that might block, or are querying the status of a task in-progress, will return a `Status`,
/// so an app can see if a task completed, and its final outcome.
///
/// ## Version
/// This enum is available since SDL_net 3.0.0.
pub const Status = enum(c.NET_Status) {
    waiting = c.NET_WAITING,
    success = c.NET_SUCCESS,

    /// Convert from an SDL value.
    pub fn fromSdl(
        value: c.NET_Status,
    ) !Status {
        if (value == -1) {
            errors.callErrorCallback();
            return error.SdlError;
        }
        return @enumFromInt(value);
    }

    /// Convert to an SDL value.
    pub fn toSdl(
        self: Status,
    ) c.NET_Status {
        return @intFromEnum(self);
    }
};

/// An object that represents a streaming connection to another system.
///
/// ## Remarks
/// This is meant to be a reliable, stream-oriented connection, such as TCP.
///
/// Each `StreamSocket` represents a single connection between systems.
/// Usually, a client app will have one connection to a server app on a different computer, and the server app might have many connections from different clients.
/// Each of these connections communicate over a separate stream socket.
///
/// ## Version
/// This datatype is available since SDL_net 3.0.0.
pub const StreamSocket = struct {
    value: *c.NET_StreamSocket,

    /// Status of a stream socket connection.
    ///
    /// ## Version
    /// This enum is available since SDL_net 3.0.0.
    pub const ConnectionStatus = enum {
        connected,
        connecting,
    };

    /// Dispose of a previously-created stream socket.
    ///
    /// ## Function Parameters
    /// * `self`: The stream socket to destroy.
    ///
    /// ## Remarks
    /// This will immediately disconnect the other side of the connection, if necessary.
    /// Further attempts to read or write the socket on the remote end will fail.
    ///
    /// This will abandon any data queued for sending that hasn't made it to the socket.
    /// If you need this data to arrive, you should wait for it to transmit before destroying the socket with `StreamSocket.getPendingWrites` or `StreamSocket.waitUntilDrained`.
    /// Any data that has arrived from the remote end of the connection that hasn't been read yet is lost.
    ///
    /// ## Thread Safety
    /// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
    /// However, different threads may access different sockets at the same time without problems.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn deinit(
        self: StreamSocket,
    ) void {
        c.NET_DestroyStreamSocket(self.value);
    }

    /// Begin connecting a socket as a client to a remote server.
    ///
    /// ## Function Parameters
    /// * `address`: The address of the remote server to connect to.
    /// * `port`: The port on the remote server to connect to.
    ///
    /// ## Return Value
    /// Returns a new `net.StreamSocket`, pending connection.
    ///
    /// ## Remarks
    /// Each `StreamSocket` represents a single connection between systems.
    /// Usually, a client app will have one connection to a server app on a different computer, and the server app might have many connections from different clients.
    /// Each of these connections communicate over a separate stream socket.
    ///
    /// Connecting is an asynchronous operation; this function does not block, and will return before the connection is complete.
    /// One has to then use `StreamSocket.waitUntilConnected` or `StreamSocket.getConnectionStatus` to see when the operation has completed, and if it was successful.
    ///
    /// Once connected, you can read and write data to the returned socket.
    /// Stream sockets are a mode of reliable transmission, which means data will be received as a stream of bytes in the order you sent it.
    /// If there are problems in transmission, the system will deal with protocol negotiation and retransmission as necessary,
    /// transparent to your app, but this means until data is available in the order sent, the remote side will not get any new data.
    /// This is the tradeoff vs datagram sockets, where data can arrive in any order, or not arrive at all, without waiting, but the sender will not know.
    ///
    /// Stream sockets don't employ any protocol (above the TCP level), so they can connect to servers that aren't using SDL net,
    /// but if you want to speak any protocol beyond an abritrary stream of bytes, such as HTTP, you'll have to implement that yourself on top of the stream socket.
    ///
    /// This function will fail if address is not finished resolving.
    ///
    /// When you are done with this connection (whether it failed to connect or not), you must dispose of it with `StreamSocket.deinit`.
    ///
    /// Unlike BSD sockets or WinSock, you specify the port as a normal integer; you do not have to byteswap it into "network order," as the library will handle that for you.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn initClient(
        address: Address,
        port: u16,
    ) !StreamSocket {
        return .{
            .value = try errors.wrapCallNull(*c.NET_StreamSocket, c.NET_CreateClient(address.value, port, 0)),
        };
    }

    /// Block until a stream socket has connected to a server.
    ///
    /// ## Function Parameters
    /// * `self`: The stream socket object to wait on.
    /// * `timeout`: The maximum time to wait for connection to complete.
    ///
    /// ## Return Value
    /// Returns `true` if successfully connected, `false` if still connecting (this function timed out).
    ///
    /// ## Thread Safety
    /// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn waitUntilConnected(
        self: StreamSocket,
        timeout: Timeout,
    ) Error!bool {
        const ret = c.NET_WaitUntilConnected(self.value, timeout.toSdl());
        if (ret < 0) {
            errors.callErrorCallback();
            return error.SdlNetError;
        }
        return ret == 1;
    }

    /// Get the remote address of a stream socket.
    ///
    /// ## Function Parameters
    /// * `self`: The stream socket to query.
    ///
    /// ## Return Value
    /// Returns the socket's remote address. The caller must call `deinit()` on the returned address.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn getAddress(
        self: StreamSocket,
    ) Error!Address {
        return .{
            .value = try errors.wrapCallNull(*c.NET_Address, c.NET_GetStreamSocketAddress(self.value)),
        };
    }

    /// Check if a stream socket is connected, without blocking.
    ///
    /// ## Function Parameters
    /// * `self`: The stream socket to query.
    ///
    /// ## Return Value
    /// Returns `net.StreamSocket.ConnectionStatus.connected` if successfully connected, or `net.StreamSocket.ConnectionStatus.connecting` if still connecting.
    ///
    /// ## Thread Safety
    /// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn getConnectionStatus(
        self: StreamSocket,
    ) Error!ConnectionStatus {
        const ret = c.NET_GetConnectionStatus(self.value);
        if (ret < 0) {
            errors.callErrorCallback();
            return error.SdlNetError;
        }
        return if (ret == 1) .connected else .connecting;
    }

    /// Send bytes over a stream socket to a remote system.
    ///
    /// ## Function Parameters
    /// * `self`: The stream socket to send data through.
    /// * `data`: the data to send.
    ///
    /// ## Thread Safety
    /// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn write(
        self: StreamSocket,
        data: []const u8,
    ) Error!void {
        return errors.wrapCallBool(c.NET_WriteToStreamSocket(self.value, data.ptr, @intCast(data.len)));
    }

    /// Query bytes still pending transmission on a stream socket.
    ///
    /// ## Function Parameters
    /// * `self`: The stream socket to query.
    ///
    /// ## Return Value
    /// Returns number of bytes still pending transmission.
    ///
    /// ## Thread Safety
    /// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn getPendingWrites(
        self: StreamSocket,
    ) Error!usize {
        const ret = c.NET_GetStreamSocketPendingWrites(self.value);
        if (ret < 0) {
            errors.callErrorCallback();
            return error.SdlNetError;
        }
        return @intCast(ret);
    }

    /// Block until all of a stream socket's pending data is sent.
    ///
    /// ## Function Parameters
    /// * `self`: The stream socket to wait on.
    /// * `timeout`: The maximum time to wait for draining to complete.
    ///
    /// ## Return Value
    /// Returns number of bytes still pending transmission.
    ///
    /// ## Thread Safety
    /// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn waitUntilDrained(
        self: StreamSocket,
        timeout: Timeout,
    ) Error!usize {
        const ret = c.NET_WaitUntilStreamSocketDrained(self.value, timeout.toSdl());
        if (ret < 0) {
            errors.callErrorCallback();
            return error.SdlNetError;
        }
        return @intCast(ret);
    }

    /// Receive bytes that a remote system sent to a stream socket.
    ///
    /// ## Function Parameters
    /// * `self`: The stream socket to receive data from.
    /// * `buf`: a buffer where received data will be collected.
    ///
    /// ## Return Value
    /// Returns number of bytes read from the stream socket (which can be less than `buf.len` or zero if none available).
    ///
    /// ## Thread Safety
    /// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn read(
        self: StreamSocket,
        buf: []u8,
    ) Error!usize {
        const ret = c.NET_ReadFromStreamSocket(self.value, buf.ptr, @intCast(buf.len));
        if (ret < 0) {
            errors.callErrorCallback();
            return error.SdlNetError;
        }
        return @intCast(ret);
    }

    /// Enable simulated stream socket failures.
    ///
    /// ## Function Parameters
    /// * `self`: The stream socket to set a failure rate on.
    /// * `percent_loss`: A number between 0 and 100. Higher means more failures. Zero to disable.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn simulatePacketLoss(
        self: StreamSocket,
        percent_loss: u8,
    ) void {
        std.debug.assert(percent_loss <= 100);
        c.NET_SimulateStreamPacketLoss(self.value, @intCast(percent_loss));
    }
};

/// SDL net version information.
///
/// ## Version
/// This struct is provided by zig-sdl3.
pub const Version = struct {
    value: c_int,

    /// SDL net version compiled against.
    ///
    /// ## Version
    /// This constant is available since SDL_net 3.0.0.
    pub const compiled_against = Version{ .value = c.SDL_NET_VERSION };

    /// Check if the SDL net version is at least greater than the given one.
    ///
    /// ## Function Parameters
    /// * `major`: The major version number.
    /// * `minor`: The minor version number.
    /// * `micro`: The micro version number.
    ///
    /// ## Return Value
    /// Returns if the net version is at least this given version.
    ///
    /// ## Version
    /// This function is available since SDL_mixer 3.0.0.
    pub fn atLeast(
        major: u32,
        minor: u32,
        micro: u32,
    ) bool {
        const ret = c.SDL_NET_VERSION_ATLEAST(
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

    /// This function gets the version of the dynamically linked SDL net library.
    ///
    /// ## Return Value
    /// Returns SDL net version.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn get() Version {
        const ret = c.NET_Version();
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

/// Error, set by a network operation.
///
/// ## Version
/// This error is provided by zig-sdl3.
pub const Error = error{
    SdlNetError,
    SdlError,
    OutOfMemory,
};

/// Specifies a timeout for a network operation.
///
/// ## Version
/// This type is provided by zig-sdl3.
pub const Timeout = union(enum) {
    /// Wait indefinitely.
    indefinite,
    /// Do not wait, check once and return immediately.
    no_wait,
    /// Wait for a specific number of milliseconds.
    milliseconds: u32,

    /// Convert to an SDL i32 value.
    pub fn toSdl(self: Timeout) i32 {
        return switch (self) {
            .indefinite => -1,
            .no_wait => 0,
            .milliseconds => |ms| @intCast(ms),
        };
    }
};

/// A socket that can be polled for input.
///
/// ## Version
/// This type is provided by zig-sdl3.
pub const Pollable = union(enum) {
    server: Server,
    stream: StreamSocket,
    datagram: DatagramSocket,

    fn toOpaque(self: Pollable) ?*anyopaque {
        return switch (self) {
            .server => |s| s.value,
            .stream => |s| s.value,
            .datagram => |s| s.value,
        };
    }
};

/// Obtain a list of local addresses on the system.
///
/// ## Return Value
/// Returns a list of `Address` objects, one for each bindable address on the system.
/// The caller must call `LocalAddressList.deinit` on the returned list when done with it.
///
/// ## Remarks
/// This returns addresses that you can theoretically bind a socket to, to accept connections from other machines at that address.
///
/// You almost never need this function; first, it's hard to tell what is a good address to bind to, without asking the user (who will likely find it equally hard to decide).
/// Second, most machines will have lots of private addresses that are accessible on the same LAN, but not public ones that are accessible from the outside Internet.
///
/// Usually it's better to use `Server.init` or `DatagramSocket.init` with a `null` address, to say "bind to all interfaces".
///
/// Pass the returned array to `LocalAddressList.deinit` when you are done with it.
/// It is safe to keep any addresses you want from this array even after calling that function, as long as you called `Address.ref` on them.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL_net 3.0.0.
pub fn getLocalAddresses() !LocalAddressList {
    var num_addresses: c_int = undefined;
    const addresses: [*]Address = @ptrCast(@alignCast(try errors.wrapCallNull([*]?*c.NET_Address, c.NET_GetLocalAddresses(&num_addresses))));
    return .{
        .addresses = addresses[0..@intCast(num_addresses)],
    };
}

/// Initialize the SDL net library.
///
/// ## Remarks
/// This must be successfully called once before (almost) any other SDL net function can be used.
/// It is safe to call this multiple times; the library will only initialize once, and won't deinitialize until `quit` has been called a matching number of times.
/// Extra attempts to init report success.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL_net 3.0.0.
pub fn init() !void {
    return errors.wrapCallBool(c.NET_Init());
}

/// Deinitialize the SDL net library.
///
/// ## Remarks
/// This must be called when done with the library, probably at the end of your program.
///
/// It is safe to call this multiple times; the library will only deinitialize once, when this function is called the same number of times as `init` was successfully called.
///
/// Once you have successfully deinitialized the library, it is safe to call `init` to reinitialize it for further use.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL_net 3.0.0.
pub fn quit() void {
    c.NET_Quit();
}

/// Enable simulated address resolution failures.
///
/// ## Function Parameters
/// * `percent_loss`: A number between 0 and 100. Higher means more failures. Zero to disable.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL_net 3.0.0.
pub fn simulateAddressResolutionLoss(
    percent_loss: u8,
) void {
    std.debug.assert(percent_loss <= 100);
    c.NET_SimulateAddressResolutionLoss(@intCast(percent_loss));
}

/// Block on multiple sockets until at least one has data available.
///
/// ## Function Parameters
/// * `allocator`: The allocator to use for temporary storage.
/// * `sockets`: an array of `net.Pollable` sockets to wait on.
/// * `timeout`: The maximum time to wait for new input to become available.
///
/// ## Return Value
/// Returns the number of items that have new input.
///
/// ## Thread Safety
/// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
///
/// ## Version
/// This function is available since SDL_net 3.0.0.
pub fn waitUntilInputAvailable(
    allocator: std.mem.Allocator,
    sockets: []const Pollable,
    timeout: Timeout,
) Error!usize {
    if (sockets.len == 0) return 0;

    var c_sockets = try allocator.alloc(?*anyopaque, sockets.len);
    defer allocator.free(c_sockets);

    for (sockets, 0..) |s, i| {
        c_sockets[i] = s.toOpaque();
    }

    const ret = c.NET_WaitUntilInputAvailable(@ptrCast(c_sockets.ptr), @intCast(c_sockets.len), timeout.toSdl());
    if (ret < 0) {
        errors.callErrorCallback();
        return error.SdlNetError;
    }
    return @intCast(ret);
}

test "net" {
    errors.refAllDeclsRecursive(@This());
}
