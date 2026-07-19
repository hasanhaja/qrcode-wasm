const result = await WebAssembly.instantiateStreaming(fetch("./core.wasm"), {
  env: {
    js_math_random: () => Math.random(),
    debug: () => console.log("Here"),
    inspect: (x: number) => console.log("INSPECT |>", x),
  },
});

type Pointer = number;

// const destroyGenerator = result.instance.exports.destroy as ((ptr: Pointer) => void);

export const generateQR = result.instance.exports.generateQR as ((ptr: Pointer, len: number) => Pointer);
export const getQR = result.instance.exports.get as ((ptr: Pointer, row: number, col: number) => boolean);
export const getSizeQR = result.instance.exports.size as ((ptr: Pointer) => number);
export const alloc = result.instance.exports.allocString as ((len: number) => Pointer);
export const free = result.instance.exports.freeString as ((ptr: Pointer, len: number) => void);

export const memory = result.instance.exports.memory as WebAssembly.Memory;

