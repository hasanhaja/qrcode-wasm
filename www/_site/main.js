import { generateQR, getQR, alloc, free, memory } from "./core.js";
const PIXEL_SIZE = 5; // px
const PIXEL_COLOR = "#000000";
const BG_COLOR = "#FFFFFF";
const size = 21;
// Give the canvas room for all of our cells and a 1px border
// around each of them.
const canvas = document.getElementById("qrcode");
canvas.height = (PIXEL_SIZE + 1) * size + 1;
canvas.width = (PIXEL_SIZE + 1) * size + 1;
const ctx = canvas.getContext("2d");
// TODO Simplify because it's a square
// const getIndex = (row: number, column: number) => {
//   return row * size + column;
// };
const wasmString = (text) => {
    const bytes = new TextEncoder().encode(text);
    const ptr = alloc(bytes.length);
    // memory.buffer can be detached/resized on growth, so grab a fresh view
    const wasmMemory = new Uint8Array(memory.buffer, ptr, bytes.length);
    wasmMemory.set(bytes);
    return { ptr, len: bytes.length };
};
export const drawCells = (text) => {
    const { ptr, len } = wasmString(text);
    const qrcode = generateQR(ptr, len);
    ctx.beginPath();
    for (let row = 0; row < size; row++) {
        for (let col = 0; col < size; col++) {
            ctx.fillStyle = getQR(qrcode, row, col)
                ? PIXEL_COLOR
                : BG_COLOR;
            ctx.fillRect(col * (PIXEL_SIZE + 1) + 1, row * (PIXEL_SIZE + 1) + 1, PIXEL_SIZE, PIXEL_SIZE);
        }
    }
    ctx.stroke();
};
drawCells("Hello world");
//# sourceMappingURL=main.js.map