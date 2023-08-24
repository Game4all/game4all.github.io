const std = @import("std");

pub fn main() !void {
    var allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = allocator.deinit();

    var file = try std.fs.cwd().openFile("test.vox", .{});
    defer file.close();

    try read_format(file.reader());
}

const ChunkHeader = extern struct {
    id: [4]u8,
    content_size: u32,
    children_size: u32,
};

/// Size of a model in voxels
const ModelSize = extern struct {
    x: u32,
    y: u32,
    z: u32,
};

const Voxel = extern struct {
    x: u8,
    y: u8,
    z: u8,
    color_index: u8,
};

const Palette = extern struct {
    // the palette encoded in ARGB hex
    colors: [256]u32,
};

pub fn read_format(reader: anytype) !void {
    // Checking file header
    const header = try reader.readBytesNoEof(4);
    if (!std.mem.eql(u8, &header, "VOX ")) {
        return error.VoxFileInvalidHeader;
    }

    // Checking file version
    const format_ver = try reader.readIntLittle(u32);
    std.log.debug("Format version: {}", .{format_ver});

    while (true) {
        read_chunk(reader) catch |err| switch (err) { // this shouldn't simply return on EOF as this will break on incomplete files
            error.EndOfStream => break,
            else => return err,
        };
    }
}

fn read_chunk(reader: anytype) !void {
    const chunk_header = try reader.readStruct(ChunkHeader);
    if (std.mem.eql(u8, &chunk_header.id, "MAIN")) { //skip this one
        return;
    } else if (std.mem.eql(u8, &chunk_header.id, "SIZE")) {
        var size = try reader.readStruct(ModelSize);
        std.log.debug("Model size: {}x{}x{}", .{ size.x, size.y, size.z });
    } else if (std.mem.eql(u8, &chunk_header.id, "XYZI")) {
        const num_voxels = try reader.readIntLittle(u32);
        std.log.debug("Number of non-empty voxels: {}", .{num_voxels});
        for (0..num_voxels) |_| {
            // parse the voxel and store it here ...
            const voxel = try reader.readStruct(Voxel);
            std.log.debug("Voxel at ({}, {}, {}) with color index {}", .{ voxel.x, voxel.y, voxel.z, voxel.color_index });
            // store the voxel somewhere
        }
    } else if (std.mem.eql(u8, &chunk_header.id, "RGBA")) {
        const palette = try reader.readStruct(Palette);
        std.log.debug("Palette: {x}", .{palette.colors});
    } else {
        std.log.debug("Skipped unknown chunk {s} (Size: {}b) (Children: {}b)", .{ chunk_header.id, chunk_header.content_size, chunk_header.children_size });
        try reader.skipBytes(chunk_header.content_size, .{});
    }
}
