import { generateQR, getQR, alloc, free, memory, getSizeQR, destroyQR } from "./core.js";

const PIXEL_SIZE = 15; // px
const PIXEL_COLOR = "#000000";
const BG_COLOR = "#FFFFFF";

const wasmString = (text: string) => {
  const bytes = new TextEncoder().encode(text);
  const ptr = alloc(bytes.length);
  
  // memory.buffer can be detached/resized on growth, so grab a fresh view
  const wasmMemory = new Uint8Array(memory.buffer, ptr, bytes.length);
  wasmMemory.set(bytes);

  return { ptr, len: bytes.length };
};


export class QrCode extends HTMLElement {
  static tagName = "qr-code";
  static attrs = {
    data: "data",
  };
  static observedAttributes = Object.values(QrCode.attrs);

  private root: ShadowRoot;
  private canvas: HTMLCanvasElement | null = null;

  private qrcodeData: string = "QRCode";

  static css = `
    :host {
      display: inline-block;

      &, *, *::before, *::after {
        box-sizing: border-box;
      }

      --_fill-color: var(--qr-code__fill, black);
      --_bg-color: var(--qr-code__background, white);
    }
  `;

  constructor() {
    super();
    this.root = this.attachShadow({ mode: "open" });
    const template = document.createElement("template");

    const sheet = new CSSStyleSheet();
    sheet.replaceSync(QrCode.css);
    this.root.adoptedStyleSheets = [sheet];
    template.innerHTML = `
      <canvas id="qrcode"></canvas>
    `;
    this.root.appendChild(template.content.cloneNode(true));
  }

  connectedCallback() {
    this.canvas = this.root.getElementById("qrcode") as HTMLCanvasElement;

    this.render(this.data);
  }

  get data() {
    return this.qrcodeData;
  }

  set data(value: string) {
    this.qrcodeData = value;
    this.render(value);
  }

  render(value: string) {
    if (!this.canvas) {
      return;
    }
    const ctx = this.canvas.getContext("2d")!;

    const { ptr, len } = wasmString(value);
    const qrcode = generateQR(ptr, len);

    const SIZE = getSizeQR(qrcode);

    this.canvas.height = PIXEL_SIZE * SIZE;
    this.canvas.width = PIXEL_SIZE * SIZE;

    ctx.beginPath();

    for (let row = 0; row < SIZE; row++) {
      for (let col = 0; col < SIZE; col++) {
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

    destroyQR(qrcode);
    free(ptr, len);
  }

  attributeChangedCallback(name: string, oldValue: string, newValue: string) {
    if (!this.isConnected) {
      return;
    }

    if (oldValue !== newValue) {
      if (name === QrCode.attrs.data) {
        this.data = newValue;
      }
    }
  }
}

if ("customElements" in window) {
  customElements.define(QrCode.tagName, QrCode);
}
