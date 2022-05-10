const std = @import("std");
const Allocator = std.mem.Allocator;

const printer = @import("./printer.zig");
const printJoin = printer.printJoin;
const reader = @import("./reader.zig");
const types = @import("./types.zig");
const MalType = types.MalType;
const Number = MalType.Number;
const Primitive = MalType.Function.Primitive;

pub fn add(a: Number, b: Number) Number {
    return a + b;
}

pub fn subtract(a: Number, b: Number) Number {
    return a - b;
}

pub fn multiply(a: Number, b: Number) Number {
    return a * b;
}

pub fn divide(a: Number, b: Number) Number {
    // TODO: use std.math.divFloor/divTrunc for runtime errors instead of
    // undefined behavior when dividing by zero
    return @divFloor(a, b);
}

pub fn lessThan(a: Number, b: Number) bool {
    return a < b;
}

pub fn lessOrEqual(a: Number, b: Number) bool {
    return a <= b;
}

pub fn greaterThan(a: Number, b: Number) bool {
    return a > b;
}

pub fn greaterOrEqual(a: Number, b: Number) bool {
    return a >= b;
}

pub fn list(allocator: Allocator, params: MalType.List) !*MalType {
    var result_ptr = try allocator.create(MalType);
    result_ptr.* = MalType{ .list = params };
    return result_ptr;
}

pub fn is_list(param: *const MalType) bool {
    return param.* == .list;
}

pub fn is_nil(param: *const MalType) bool {
    return param.* == .atom and param.atom == .nil;
}

pub fn is_empty(param: *const MalType) bool {
    return count(param) == 0;
}

pub fn count(param: *const MalType) Number {
    if (is_list(param))
        return @intCast(Number, param.list.items.len)
    else if (is_nil(param))
        return 0
    else
        // TODO: error if not list?
        return -1;
}

pub fn eql(a: *const MalType, b: *const MalType) bool {
    return a.equals(b);
}

pub fn pr_str(allocator: Allocator, args: MalType.List) !*MalType {
    var result_ptr = try allocator.create(MalType);
    result_ptr.* = MalType.makeString(allocator, try printJoin(allocator, "", args, true));
    return result_ptr;
}

pub fn str(allocator: Allocator, args: MalType.List) !*MalType {
    var result_ptr = try allocator.create(MalType);
    result_ptr.* = MalType.makeString(allocator, try printJoin(allocator, "", args, false));
    return result_ptr;
}

pub fn prn(allocator: Allocator, args: MalType.List) !*MalType {
    const string = try printJoin(allocator, " ", args, true);
    defer allocator.free(string);

    const stdout = std.io.getStdOut().writer();
    try stdout.print("{s}\n", .{string});

    // TODO: this shouldn't need to allocate
    var result_ptr = try allocator.create(MalType);
    result_ptr.* = .{ .atom = .nil };
    return result_ptr;
}

pub fn println(allocator: Allocator, args: MalType.List) !*MalType {
    const string = try printJoin(allocator, " ", args, false);
    defer allocator.free(string);

    const stdout = std.io.getStdOut().writer();
    try stdout.print("{s}\n", .{string});

    // TODO: this shouldn't need to allocate
    var result_ptr = try allocator.create(MalType);
    result_ptr.* = .{ .atom = .nil };
    return result_ptr;
}

pub fn read_string(allocator: Allocator, param: *const MalType) !*MalType {
    const string = try param.asString();
    var ast = try reader.read_str(allocator, string.value);
    return &ast;
}

pub fn slurp(allocator: Allocator, param: *const MalType) !*MalType {
    const file_name = try param.asString();
    const file = try std.fs.cwd().openFile(file_name.value, .{});
    defer file.close();
    // TODO: revisit global max size definitions
    const max_size = 1 << 16; // 64KiB
    const contents = try file.reader().readAllAlloc(allocator, max_size);
    return &MalType{ .atom = .{ .string = .{
        .value = contents,
        .allocator = allocator,
    } } };
}

pub const ns = .{
    .@"+" = Primitive.make(add),
    .@"-" = Primitive.make(subtract),
    .@"*" = Primitive.make(multiply),
    .@"/" = Primitive.make(divide),
    .@"<" = Primitive.make(lessThan),
    .@"<=" = Primitive.make(lessOrEqual),
    .@">" = Primitive.make(greaterThan),
    .@">=" = Primitive.make(greaterOrEqual),
    .@"=" = Primitive.make(eql),
    .@"list" = Primitive.make(list),
    .@"list?" = Primitive.make(is_list),
    .@"empty?" = Primitive.make(is_empty),
    .@"nil?" = Primitive.make(is_nil),
    .@"count" = Primitive.make(count),
    .@"pr-str" = Primitive.make(pr_str),
    .@"str" = Primitive.make(str),
    .@"prn" = Primitive.make(prn),
    .@"println" = Primitive.make(println),
    .@"read-string" = Primitive.make(read_string),
    .@"slurp" = Primitive.make(slurp),
};
