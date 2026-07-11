import * as qrcodeMod from "./qr-code.js";

const qrcode = document.querySelector("qr-code") as qrcodeMod.QrCode;
const form = document.querySelector("form") as HTMLFormElement;

form.addEventListener("submit", (e) => {
  e.preventDefault();
  const formData = new FormData(form);

  if (formData.get("text")) {
    qrcode.data = formData.get("text") as string;
  }
});
