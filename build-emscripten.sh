#!/usr/bin/bash

# !! make sure to install emsdk, clang, lld (wasm-ld) !!
# (run these as root):
# `emsdk install latest` (or whatever version you need, 3.1.50 worked for me:tm:)
# `/usr/lib/emsdk/upstream/emscripten/emcc --generate-config`

# Used to finding assets in res/
ls -NAU1 --color=never res >| src/res.txt

# This will output the project to zig-out/htmlout
zig build -Dtarget=wasm32-emscripten --sysroot /usr/lib/emsdk/upstream/emscripten $@
