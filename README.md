# zig-docsearch

**NOTE: zig master now has in-progress docs! see https://github.com/ziglang/zig/issues/21**

search over zig stdlib doc comments (and generate a simple html file with
what's possible)

WIP: using -fdump-analysis

## using

firstly, build the semantic analysis file from the zig standard library.

```
zig test path/to/std/std.zig -fdump-analysis --override-lib-dir path/to/lib/if/needed --output-dir . -fno-emit-bin
```

build and use zig-docsearch

```bash
zig build

# search through
zig-docsearch ./test-analysis.json search 'mem'

# make a single html file (WIP)
zig-docsearch ./state.bin htmlgen index.html
```
