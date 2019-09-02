# zig-docsearch

search over zig stdlib doc comments (and generate a simple html file with
what's possible)

## limitations

 - structs with `@import`s won't be checked
 - structs that don't have `pub` members will still be counted towards the end
 - search algorithm is very rudimentary

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
