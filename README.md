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

## Usage

Build the full application using `make build`.

It will do the following:

- Compile the Zig code to WASM
- Compile the TypeScript code to JavaScript
- Copy the WASM binary to the `_site` output directory

Serve `www/_site` locally with any HTTP server, like `python -m http.server`. This is what `make run` does. 

## Future considerations

I'm currently using the ReleaseSmall flag and the `page_allocator` to keep the WASM binary small, but following the techniques from the original tutorial might help me get it down even smaller: https://rustwasm.github.io/docs/book/game-of-life/code-size.html

Another thing I'd like to explore as a part of this is translating the WASM file to the WAT format to try and understand some of the assembly code.
