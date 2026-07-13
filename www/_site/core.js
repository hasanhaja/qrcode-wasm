const result = await WebAssembly.instantiateStreaming(fetch("./core.wasm"), {
    env: {
        js_math_random: () => Math.random(),
        debug: () => console.log("Here"),
        inspect: (x) => console.log("INSPECT |>", x),
    },
});
// const destroyGenerator = result.instance.exports.destroy as ((ptr: Pointer) => void);
export const generateQR = result.instance.exports.generateQR;
export const getQR = result.instance.exports.get;
export const alloc = result.instance.exports.allocString;
export const free = result.instance.exports.freeString;
export const memory = result.instance.exports.memory;
//# sourceMappingURL=core.js.map