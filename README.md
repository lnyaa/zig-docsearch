# zig-docsearch

search over zig stdlib doc comments

## limitations

 - structs with `@import`s won't be checked
 - structs that don't have `pub` members will still be counted towards the end

## using

```bash
zig build install --prefix ~/.local/

# build the state out of the std file
zig-docsearch build /path/to/zig/source/std/std.zig
```
