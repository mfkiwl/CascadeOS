// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Lee Cannon <leecannon@leecannon.xyz>

//! Singly linked LIFO (last in first out).
//!
//! Provides thread-safety using atomic operations.

const AtomicSinglyLinkedLIFO = @This();

start_node: std.atomic.Value(?*SingleNode) = .init(null),

pub const empty: AtomicSinglyLinkedLIFO = .{ .start_node = .init(null) };

/// Returns `true` if the list is empty.
pub fn isEmpty(atomic_singly_linked_lifo: *const AtomicSinglyLinkedLIFO) bool {
    return atomic_singly_linked_lifo.start_node.load(.acquire) == null;
}

/// Adds a node to the front of the list.
pub fn push(atomic_singly_linked_lifo: *AtomicSinglyLinkedLIFO, node: *SingleNode) void {
    atomic_singly_linked_lifo.pushMany(node, node);
}

/// Adds a linked list of nodes to the front of the list.
///
/// The list is expected to be already linked correctly.
pub fn pushMany(
    atomic_singly_linked_lifo: *AtomicSinglyLinkedLIFO,
    start_node: *SingleNode,
    end_node: *SingleNode,
) void {
    var opt_start_node = atomic_singly_linked_lifo.start_node.load(.monotonic);

    while (true) {
        end_node.next = opt_start_node;

        if (atomic_singly_linked_lifo.start_node.cmpxchgWeak(
            opt_start_node,
            start_node,
            .release,
            .monotonic,
        )) |new_value| {
            opt_start_node = new_value;
            continue;
        }

        return;
    }
}

/// Removes a node from the front of the list and returns it.
pub fn pop(atomic_singly_linked_lifo: *AtomicSinglyLinkedLIFO) ?*SingleNode {
    var opt_start_node = atomic_singly_linked_lifo.start_node.load(.monotonic);

    while (opt_start_node) |start_node| {
        if (atomic_singly_linked_lifo.start_node.cmpxchgWeak(
            opt_start_node,
            start_node.next,
            .release,
            .monotonic,
        )) |new_value| {
            opt_start_node = new_value;
            continue;
        }

        start_node.* = .empty;
        return start_node;
    }

    return null;
}

test AtomicSinglyLinkedLIFO {
    const NODE_COUNT = 10;

    var lifo: AtomicSinglyLinkedLIFO = .empty;

    // starts empty
    try std.testing.expect(lifo.isEmpty());

    var nodes = [_]SingleNode{.empty} ** NODE_COUNT;

    for (&nodes) |*node| {
        // add node to the front of the list
        lifo.push(node);
        try std.testing.expect(!lifo.isEmpty());
        try std.testing.expect(!lifo.isEmpty());

        // popping the node should return the node just added
        const first_node = lifo.pop() orelse return error.NonEmptyListHasNoNode;
        try std.testing.expect(first_node == node);

        // add the popped node back to the list
        lifo.push(node);
    }

    // nodes are popped in the opposite order they were pushed
    var i: usize = NODE_COUNT;
    while (i > 0) {
        i -= 1;

        const node = lifo.pop() orelse
            return error.ExpectedNode;

        try std.testing.expect(node == &nodes[i]);
    }

    // list is empty again
    try std.testing.expect(lifo.isEmpty());
}

comptime {
    std.testing.refAllDeclsRecursive(@This());
}

const std = @import("std");
const core = @import("core");
const containers = @import("containers");

const SingleNode = containers.SingleNode;
