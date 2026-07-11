import * as qrcodeMod from "./qr-code.js";
const qrcode = document.querySelector("qr-code");
const form = document.querySelector("form");
form.addEventListener("submit", (e) => {
    e.preventDefault();
    const formData = new FormData(form);
    if (formData.get("text")) {
        qrcode.data = formData.get("text");
    }
});
//# sourceMappingURL=main.js.map