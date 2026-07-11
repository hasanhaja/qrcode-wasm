import { generateQR, getQR, alloc, free, memory } from "./core.js";

const PIXEL_SIZE = 25; // px
const PIXEL_COLOR = "#000000";
const BG_COLOR = "#FFFFFF";

const size = 21;

const canvas = document.getElementById("qrcode") as HTMLCanvasElement;
canvas.height = PIXEL_SIZE * size;
canvas.width = PIXEL_SIZE * size;

const ctx = canvas.getContext("2d")!;

const wasmString = (text: string) => {
  const bytes = new TextEncoder().encode(text);
  const ptr = alloc(bytes.length);
  
  // memory.buffer can be detached/resized on growth, so grab a fresh view
  const wasmMemory = new Uint8Array(memory.buffer, ptr, bytes.length);
  wasmMemory.set(bytes);

  return { ptr, len: bytes.length };
};

export const drawCells = (text: string) => {
  const { ptr, len } = wasmString(text);
  const qrcode = generateQR(ptr, len);

  ctx.beginPath();

  for (let row = 0; row < size; row++) {
    for (let col = 0; col < size; col++) {
      ctx.fillStyle = getQR(qrcode, row, col)
        ? PIXEL_COLOR
        : BG_COLOR;

      ctx.fillRect(
        col * PIXEL_SIZE,
        row * PIXEL_SIZE,
        PIXEL_SIZE,
        PIXEL_SIZE
      );
    }
  }

  free(ptr, len);
};

drawCells("WASM is cool");
