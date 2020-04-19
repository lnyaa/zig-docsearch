# zig-docsearch

**NOTE: zig master now has in-progress docs! see https://github.com/ziglang/zig/issues/21**

search over zig stdlib doc comments (and generate a simple html file with
what's possible)

WIP: using -fdump-analysis

## using

```bash
zig build install --prefix ~/.local/
```

```bash
# build the state out of the std file in your zig installation
zig-docsearch ./state.bin build /path/to/zig/source/std/std.zig

# search through
zig-docsearch ./state.bin search 'mem'

# make a single html file
zig-docsearch ./state.bin htmlgen index.html
```
