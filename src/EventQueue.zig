const std = @import("std");
const Event = @import("event.zig").Event;

events: List,
lock: std.Thread.Mutex,
condition: std.Thread.Condition,
allocator: std.mem.Allocator,
consumer_id: AtomicThreadId,

const Queue = @This();
const Item = Event.ReadError!Event;
const List = std.DoublyLinkedList;
const Node = struct {
    node: List.Node,
    item: Item,
};
const AtomicThreadId = std.atomic.Value(std.Thread.Id);

pub fn init(allocator: std.mem.Allocator) Queue {
    var queue = Queue{
        .events = .{},
        .lock = .{},
        .condition = .{},
        .allocator = allocator,
        .consumer_id = AtomicThreadId.init(std.Thread.getCurrentId()),
    };
    queue.lock.lock(); // wait() unlocks the lock
    return queue;
}

pub fn listenStdin(queue: *Queue, stdin: std.fs.File) !void {
    const thread = try std.Thread.spawn(.{}, struct {
        fn listen(in: std.fs.File) void {
            while (true) {
                const event = Event.next(in);
                (global_queue orelse break).enqueue(event) catch continue;
            }
        }
    }.listen, .{stdin});
    thread.detach();
    global_queue = queue;
}

var global_queue: ?*Queue = null;
/// Sets the global SIGWINCH handler to enqueue a resize event
pub fn listenSigwinch(queue: *Queue) void {
    var sa: std.posix.Sigaction = .{
        .handler = .{
            .handler = struct {
                fn handler(signum: c_int) callconv(.C) void {
                    std.debug.assert(signum == std.posix.SIG.WINCH);
                    if (global_queue) |q| {
                        if (std.Thread.getCurrentId() == q.consumer_id.load(.seq_cst)) {
                            // don't bother locking if the queue is waiting on the same thread
                            // this scenario may occur because signals are weird
                            const node = q.allocator.create(Node) catch return;
                            node.* = .{ .node = .{}, .item = .resize };
                            q.events.prepend(&node.node);
                            q.condition.signal();
                        } else {
                            q.enqueue(.resize) catch return;
                        }
                    }
                }
            }.handler,
        },
        .mask = std.posix.empty_sigset,
        .flags = std.posix.SA.RESTART,
    };
    std.posix.sigaction(std.posix.SIG.WINCH, &sa, null);
    global_queue = queue;
}

pub fn deinit(queue: *Queue) void {
    global_queue = null;
    while (queue.events.pop()) |node| {
        queue.allocator.destroy(node);
    }
}

fn enqueue(queue: *Queue, event: Item) !void {
    {
        queue.lock.lock();
        defer queue.lock.unlock();
        const node = try queue.allocator.create(Node);
        errdefer queue.allocator.destroy(node);
        node.* = .{ .node = .{}, .item = event };
        queue.events.prepend(&node.node);
    }
    queue.condition.signal();
}

pub fn wait(queue: *Queue) !Event {
    queue.consumer_id.store(std.Thread.getCurrentId(), .seq_cst);

    while (queue.events.first == null) {
        queue.condition.wait(&queue.lock);
    }

    const node = queue.events.pop() orelse unreachable;
    const node_ptr = @as(*Node, @fieldParentPtr("node", node));
    defer queue.allocator.destroy(node_ptr);

    return node_ptr.item;
}

/// clears the queue, assuming it is in a non-waiting state
pub fn clear(queue: *Queue) !void {
    while (queue.events.pop()) |node| {
        const node_ptr = @as(*Node, @fieldParentPtr("node", node));
        queue.allocator.destroy(node_ptr);
        _ = try node_ptr.item;
    }
}
