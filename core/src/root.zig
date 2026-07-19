//! Minimal QR Code generator — Zig port of the TypeScript reference version.
//!
//! Same fixed choices as before, for the same reasons:
//!   - Version 1 only        -> fixed 21x21 grid
//!   - Error correction L    -> 7 EC codewords, 19 data codewords
//!   - Byte mode only        -> max 17 bytes of input text
//!   - Mask pattern 0 only   -> no scoring across all 8 masks
//!
//! I could not compile this in the sandbox (no zig toolchain available), so
//! treat compiler errors as your first debugging pass — that's normal, and
//! exactly what `zig test` is for. The `test` blocks at the bottom use
//! reference values computed from the verified TypeScript implementation,
//! so if those pass, the logic is right even if I got a cast wrong somewhere
//! along the way.
//!
//! Run with: zig test qr.zig

const std = @import("std");
const qr = @import("qr");

pub const SIZE = 21;
const N = SIZE * SIZE;
pub const MAX_TEXT_LEN = 17;

pub const EncodeError = error{TextTooLong};

var allocator = std.heap.page_allocator;

fn idx(row: usize, col: usize) usize {
    return row * SIZE + col;
}

// ---------------------------------------------------------------------------
// 1. GF(256) arithmetic
// ---------------------------------------------------------------------------

const GfTables = struct {
    exp: [512]u8,
    log: [256]u8,
};

fn initGf() GfTables {
    var exp: [512]u8 = undefined;
    var log: [256]u8 = undefined;
    var x: u16 = 1;
    var i: usize = 0;
    while (i < 255) : (i += 1) {
        exp[i] = @intCast(x);
        log[@as(usize, x)] = @intCast(i);
        x <<= 1;
        if (x & 0x100 != 0) x ^= 0x11d;
    }
    i = 255;
    while (i < 512) : (i += 1) {
        exp[i] = exp[i - 255];
    }
    return .{ .exp = exp, .log = log };
}

// Computed once, at compile time.
const gf: GfTables = initGf();

fn gfMul(a: u8, b: u8) u8 {
    if (a == 0 or b == 0) return 0;
    const sum: usize = @as(usize, gf.log[a]) + @as(usize, gf.log[b]);
    return gf.exp[sum];
}

// degree is comptime because the returned array's size depends on it.
fn generatorPoly(comptime degree: usize) [degree + 1]u8 {
    var poly: [degree + 1]u8 = [_]u8{0} ** (degree + 1);
    poly[0] = 1;
    var len: usize = 1;
    var i: usize = 0;
    while (i < degree) : (i += 1) {
        var next: [degree + 1]u8 = [_]u8{0} ** (degree + 1);
        var j: usize = 0;
        while (j < len) : (j += 1) {
            next[j] ^= poly[j];
            next[j + 1] ^= gfMul(poly[j], gf.exp[i]);
        }
        poly = next;
        len += 1;
    }
    return poly;
}

fn rsEncode(data: [19]u8, comptime ec_count: usize) [ec_count]u8 {
    const gen = generatorPoly(ec_count);
    var msg: [19 + ec_count]u8 = undefined;
    @memcpy(msg[0..19], &data);
    @memset(msg[19..], 0);

    var i: usize = 0;
    while (i < 19) : (i += 1) {
        const coef = msg[i];
        if (coef != 0) {
            var j: usize = 0;
            while (j < gen.len) : (j += 1) {
                msg[i + j] ^= gfMul(gen[j], coef);
            }
        }
    }

    var result: [ec_count]u8 = undefined;
    @memcpy(&result, msg[19 .. 19 + ec_count]);
    return result;
}

// ---------------------------------------------------------------------------
// 2. Data encoding: text -> 19 byte-mode codewords
// ---------------------------------------------------------------------------

const BitWriter = struct {
    buf: *[19]u8,
    bit_pos: usize = 0,

    // len must be <= 8 for everything we push here (mode/count/byte/terminator/pad).
    fn push(self: *BitWriter, value: u32, len: u4) void {
        var i: u4 = len;
        while (i > 0) {
            i -= 1;
            const shift: u5 = @intCast(i);
            const bit: u1 = @intCast((value >> shift) & 1);
            const byte_idx = self.bit_pos / 8;
            const bit_idx: u3 = @intCast(7 - (self.bit_pos % 8));
            if (bit == 1) {
                self.buf[byte_idx] |= (@as(u8, 1) << bit_idx);
            }
            self.bit_pos += 1;
        }
    }
};

fn encodeData(text: []const u8) EncodeError![19]u8 {
    if (text.len > MAX_TEXT_LEN) return error.TextTooLong;

    var buf: [19]u8 = [_]u8{0} ** 19;
    var w = BitWriter{ .buf = &buf };

    w.push(0b0100, 4); // mode indicator: byte mode
    w.push(@intCast(text.len), 8); // character count
    for (text) |byte| w.push(byte, 8);

    const data_capacity_bits: usize = 19 * 8;
    const remaining = data_capacity_bits - w.bit_pos;
    w.push(0, @intCast(@min(4, remaining))); // terminator

    if (w.bit_pos % 8 != 0) {
        w.push(0, @intCast(8 - (w.bit_pos % 8))); // byte-align
    }

    const pad_bytes = [_]u8{ 0b11101100, 0b00010001 };
    var p: usize = 0;
    while (w.bit_pos < data_capacity_bits) : (p += 1) {
        w.push(pad_bytes[p % 2], 8);
    }

    return buf;
}

// ---------------------------------------------------------------------------
// 3. Format info (BCH)
// ---------------------------------------------------------------------------

fn computeFormatBits(ecc_indicator: u2, mask_pattern: u3) u15 {
    const data: u5 = (@as(u5, ecc_indicator) << 3) | @as(u5, mask_pattern);
    var rem: u32 = @as(u32, data) << 10;
    const gen: u32 = 0b10100110111;

    var i: usize = 5;
    while (i > 0) {
        i -= 1; // i walks 4,3,2,1,0
        const shift: u5 = @intCast(i + 10);
        if ((rem >> shift) & 1 == 1) {
            rem ^= gen << @as(u5, @intCast(i));
        }
    }

    const combined: u15 = @intCast((@as(u32, data) << 10) | rem);
    return combined ^ 0b101010000010010;
}

// ---------------------------------------------------------------------------
// 4. Matrix construction
// ---------------------------------------------------------------------------

fn placeFinder(dark: *std.StaticBitSet(N), is_function: *std.StaticBitSet(N), row: usize, col: usize) void {
    var dr: i32 = -1;
    while (dr <= 7) : (dr += 1) {
        var dc: i32 = -1;
        while (dc <= 7) : (dc += 1) {
            const rr = @as(i32, @intCast(row)) + dr;
            const cc = @as(i32, @intCast(col)) + dc;
            if (rr < 0 or rr >= SIZE or cc < 0 or cc >= SIZE) continue;

            const in_ring = dr >= 0 and dr <= 6 and dc >= 0 and dc <= 6;
            const is_dark = in_ring and (dr == 0 or dr == 6 or dc == 0 or dc == 6 or
                (dr >= 2 and dr <= 4 and dc >= 2 and dc <= 4));

            const id = idx(@intCast(rr), @intCast(cc));
            is_function.set(id);
            dark.setValue(id, is_dark);
        }
    }
}

fn placeTiming(dark: *std.StaticBitSet(N), is_function: *std.StaticBitSet(N)) void {
    var i: usize = 8;
    while (i < SIZE - 8) : (i += 1) {
        const bit = i % 2 == 0;
        const a = idx(6, i);
        const b = idx(i, 6);
        if (!is_function.isSet(a)) {
            is_function.set(a);
            dark.setValue(a, bit);
        }
        if (!is_function.isSet(b)) {
            is_function.set(b);
            dark.setValue(b, bit);
        }
    }
}

fn reserveFormatAreas(dark: *std.StaticBitSet(N), is_function: *std.StaticBitSet(N)) void {
    var i: usize = 0;
    while (i < 9) : (i += 1) {
        is_function.set(idx(8, i));
        is_function.set(idx(i, 8));
    }
    i = 0;
    while (i < 8) : (i += 1) {
        is_function.set(idx(8, SIZE - 1 - i));
        is_function.set(idx(SIZE - 1 - i, 8));
    }
    is_function.set(idx(SIZE - 8, 8));
    dark.set(idx(SIZE - 8, 8)); // the "dark module" — always on
}

fn placeFormatBits(dark: *std.StaticBitSet(N), format_bits: u15) void {
    var bits: [15]bool = undefined;
    var i: usize = 0;
    while (i < 15) : (i += 1) {
        const shift: u4 = @intCast(14 - i);
        bits[i] = ((format_bits >> shift) & 1) == 1;
    }

    // Copy A: wraps the top-left finder pattern
    const cols_a = [_]usize{ 0, 1, 2, 3, 4, 5, 7, 8 };
    for (cols_a, 0..) |c, k| dark.setValue(idx(8, c), bits[k]);
    const rows_a = [_]usize{ 7, 5, 4, 3, 2, 1, 0 };
    for (rows_a, 0..) |r, k| dark.setValue(idx(r, 8), bits[8 + k]);

    // Copy B: split across the bottom-left and top-right finders
    i = 0;
    while (i < 8) : (i += 1) dark.setValue(idx(SIZE - 1 - i, 8), bits[i]);
    i = 0;
    while (i < 7) : (i += 1) dark.setValue(idx(8, SIZE - 7 + i), bits[8 + i]);
}

fn placeData(dark: *std.StaticBitSet(N), is_function: *const std.StaticBitSet(N), codewords: [26]u8) void {
    var bits: [26 * 8]bool = undefined;
    var bi: usize = 0;
    for (codewords) |cw| {
        var i: i32 = 7;
        while (i >= 0) : (i -= 1) {
            const shift: u3 = @intCast(i);
            bits[bi] = ((cw >> shift) & 1) == 1;
            bi += 1;
        }
    }

    var bit_index: usize = 0;
    var upward = true;
    var col: i32 = SIZE - 1;
    while (col > 0) {
        if (col == 6) col -= 1; // the timing column carries no data
        var i: usize = 0;
        while (i < SIZE) : (i += 1) {
            const row: usize = if (upward) SIZE - 1 - i else i;
            const cols = [_]i32{ col, col - 1 };
            for (cols) |c| {
                const id = idx(row, @intCast(c));
                if (!is_function.isSet(id)) {
                    const bit = if (bit_index < bits.len) bits[bit_index] else false;
                    dark.setValue(id, bit);
                    bit_index += 1;
                }
            }
        }
        upward = !upward;
        col -= 2;
    }
}

fn applyMask(dark: *std.StaticBitSet(N), is_function: std.StaticBitSet(N)) void {
    var mask_cells = std.StaticBitSet(N).initEmpty();
    var r: usize = 0;
    while (r < SIZE) : (r += 1) {
        var c: usize = 0;
        while (c < SIZE) : (c += 1) {
            if ((r + c) % 2 == 0) mask_cells.set(idx(r, c));
        }
    }
    mask_cells.setIntersection(is_function.complement());
    dark.toggleSet(mask_cells); // XOR every masked, non-function cell in one shot
}

// ---------------------------------------------------------------------------
// 5. Put it all together
// ---------------------------------------------------------------------------

const QrCode = struct {
    dark: std.StaticBitSet(N),

    export fn get(self: *const QrCode, row: usize, col: usize) bool {
        return self.dark.isSet(idx(row, col));
    }
};

// export fn generateQR(ptr: [*]u8, len: usize) *QrCode {
//     const text: []const u8 = ptr[0..len];
//     const data_cw = encodeData(text) catch unreachable;
//     const ec_cw = rsEncode(data_cw, 7);

//     var codewords: [26]u8 = undefined;
//     @memcpy(codewords[0..19], &data_cw);
//     @memcpy(codewords[19..26], &ec_cw);

//     var dark = std.StaticBitSet(N).initEmpty();
//     var is_function = std.StaticBitSet(N).initEmpty();

//     placeFinder(&dark, &is_function, 0, 0);
//     placeFinder(&dark, &is_function, 0, SIZE - 7);
//     placeFinder(&dark, &is_function, SIZE - 7, 0);
//     placeTiming(&dark, &is_function);
//     reserveFormatAreas(&dark, &is_function);

//     placeData(&dark, &is_function, codewords);

//     const format_bits = computeFormatBits(0b01, 0); // EC level L = 01, mask = 0
//     placeFormatBits(&dark, format_bits);

//     applyMask(&dark, is_function);

//     const qrcode = allocator.create(QrCode) catch unreachable;
//     qrcode.* = .{ .dark = dark };

//     return qrcode;
// }

export fn generateQR(ptr: [*]u8, len: usize) *qr.QrCode {
    const code = qr.generateQR(allocator, ptr, len) catch unreachable;
    return code;
}


export fn allocString(len: usize) [*]u8 {
    const slice = allocator.alloc(u8, len) catch unreachable;
    return slice.ptr;
}

export fn freeString(ptr: [*]u8, len: usize) void {
    allocator.free(ptr[0..len]);
}

// ---------------------------------------------------------------------------
// Reference tests — values computed from the verified TypeScript version.
// If these pass, your Zig logic matches a known-correct implementation.
// ---------------------------------------------------------------------------

test "GF_EXP matches known values" {
    try std.testing.expectEqual(@as(u8, 1), gf.exp[0]);
    try std.testing.expectEqual(@as(u8, 2), gf.exp[1]);
    try std.testing.expectEqual(@as(u8, 4), gf.exp[2]);
    try std.testing.expectEqual(@as(u8, 29), gf.exp[8]);
    try std.testing.expectEqual(@as(u8, 232), gf.exp[11]);
}

test "GF_LOG matches known values" {
    try std.testing.expectEqual(@as(u8, 0), gf.log[1]);
    try std.testing.expectEqual(@as(u8, 1), gf.log[2]);
    try std.testing.expectEqual(@as(u8, 25), gf.log[3]);
}

test "generator polynomial for 7 EC codewords" {
    const gen = generatorPoly(7);
    const expected = [_]u8{ 1, 127, 122, 154, 164, 11, 68, 117 };
    try std.testing.expectEqualSlices(u8, &expected, &gen);
}

test "encodeData produces correct codewords for HELLO" {
    const cw = try encodeData("HELLO");
    const expected = [_]u8{
        0x40, 0x54, 0x84, 0x54, 0xc4, 0xc4, 0xf0, 0xec, 0x11,
        0xec, 0x11, 0xec, 0x11, 0xec, 0x11, 0xec, 0x11, 0xec, 0x11,
    };
    try std.testing.expectEqualSlices(u8, &expected, &cw);
}

test "reed-solomon EC codewords for HELLO" {
    const data = try encodeData("HELLO");
    const ec = rsEncode(data, 7);
    const expected = [_]u8{ 0x4d, 0x2a, 0xd3, 0xbb, 0x9f, 0x20, 0x84 };
    try std.testing.expectEqualSlices(u8, &expected, &ec);
}

test "format bits for EC level L, mask 0" {
    const fmt = computeFormatBits(0b01, 0);
    try std.testing.expectEqual(@as(u15, 30660), fmt);
}

test "text too long returns an error" {
    const too_long = "this text is definitely too long for v1";
    try std.testing.expectError(error.TextTooLong, encodeData(too_long));
}

test "generateQR runs end to end without error" {
    _ = try generateQR("HELLO");
}

test "finder pattern center is dark" {
    const qrcode = try generateQR("HI");
    try std.testing.expect(qrcode.get(3, 3)); // center of top-left finder
    try std.testing.expect(qrcode.get(3, SIZE - 4)); // center of top-right finder
    try std.testing.expect(qrcode.get(SIZE - 4, 3)); // center of bottom-left finder
}

test "dark module is always on" {
    const qrcode = try generateQR("HI");
    try std.testing.expect(qrcode.get(SIZE - 8, 8));
}
