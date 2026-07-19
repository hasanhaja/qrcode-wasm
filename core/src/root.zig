const std = @import("std");
const qr = @import("qr");

var allocator = std.heap.page_allocator;

export fn generateQR(ptr: [*]u8, len: usize) *qr.QrCode {
    const code = qr.generateQR(allocator, ptr, len) catch unreachable;
    return code;
}

export fn destroy(qrCode: *qr.QrCode) void {
    qrCode.deinit();
}

export fn allocString(len: usize) [*]u8 {
    const slice = allocator.alloc(u8, len) catch unreachable;
    return slice.ptr;
}

export fn freeString(ptr: [*]u8, len: usize) void {
    allocator.free(ptr[0..len]);
}
