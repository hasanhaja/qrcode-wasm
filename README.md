# QR Code generator in WASM

## Motivation

## Stack

- Zig and the standard toolchain to generate the WASM library
- Zig's built-in `wasm_allocator` so that I can generate a freestanding binary
- ES Modules
- TypeScript and `tsc`
- Matt Pocock's `@total-typescript/tsconfig` to get up and running quickly with TypeScript

## Pre-requisites

For compilation and execution:

- Zig 0.16.0
- Node.js v25


TODO Replace section with `Makefile` scripts

Executing the `run.sh` script does the following:

- Compile the Zig code to WASM
- Compile the TypeScript code to JavaScript
- Copy the WASM binary to the `_site` output directory
- Serve `_site` with a HTTP server

For execution only, serve `www/_site` with any HTTP server. I'm using `npx serve` here.

## Future considerations

I'm currently using the ReleaseSmall flag and the `wasm_allocator` to keep the WASM binary small, but following the techniques from the original tutorial might help me get it down even smaller: https://rustwasm.github.io/docs/book/game-of-life/code-size.html

Another thing I'd like to explore as a part of this is translating the WASM file to the WAT format to try and understand some of the assembly code.
