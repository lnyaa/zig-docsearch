# zig-docsearch

search over zig stdlib doc comments

## limitations

 - structs with `@import`s won't be checked
 - structs that don't have `pub` members will still be counted towards the end
 - search algorithm is very rudimentary

## using

```bash
zig build install --prefix ~/.local/

# build the state out of the std file in your zig installation
zig-docsearch ./state.bin build /path/to/zig/source/std/std.zig

# search through
zig-docsearch ./state.bin search 'mem'
```
