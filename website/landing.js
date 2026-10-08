const previewImage = document.querySelector("#desktop-image");
const previewLink = document.querySelector(".preview-image");
const previewCaption = document.querySelector("#preview-caption");
const previewControls = document.querySelector(".preview-controls");
const previewButtons = [...previewControls.querySelectorAll("button")];

previewControls.hidden = false;
previewButtons.forEach((button) => {
  button.addEventListener("click", () => {
    previewImage.src = button.dataset.image;
    previewImage.alt = button.dataset.alt;
    previewLink.href = button.dataset.image;
    previewLink.setAttribute(
      "aria-label",
      `Enlarge screenshot: ${button.dataset.caption}`,
    );
    const caption = document.createElement("span");
    caption.textContent = button.dataset.caption;
    previewCaption.replaceChildren(`${button.textContent.trim()} `, caption);
    previewButtons.forEach((item) =>
      item.setAttribute("aria-pressed", String(item === button)),
    );
  });
});

const lightbox = document.querySelector(".lightbox");
const enlargedImage = lightbox.querySelector("img");
if (typeof lightbox.showModal === "function") {
  previewLink.addEventListener("click", (event) => {
    event.preventDefault();
    enlargedImage.src = previewImage.src;
    enlargedImage.alt = previewImage.alt;
    lightbox.showModal();
  });
  lightbox
    .querySelector("button")
    .addEventListener("click", () => lightbox.close());
  lightbox.addEventListener("keydown", (event) => {
    if (event.key === "Tab") {
      event.preventDefault();
      lightbox.querySelector("button").focus();
    }
  });
  lightbox.addEventListener("click", (event) => {
    if (event.target !== lightbox) return;
    const bounds = lightbox.getBoundingClientRect();
    if (
      event.clientX < bounds.left ||
      event.clientX > bounds.right ||
      event.clientY < bounds.top ||
      event.clientY > bounds.bottom
    )
      lightbox.close();
  });
  lightbox.addEventListener("close", () => previewLink.focus());
}

const copyButton = document.querySelector(".copy-button");
const copyStatus = document.querySelector(".copy-status");
if (navigator.clipboard?.writeText) {
  copyButton.hidden = false;
  copyButton.addEventListener("click", async () => {
    try {
      await navigator.clipboard.writeText(
        document.querySelector("#install-command").textContent.trim(),
      );
      copyStatus.textContent = "Command copied.";
    } catch {
      copyStatus.textContent = "Select the command to copy it manually.";
      const selection = window.getSelection();
      const range = document.createRange();
      range.selectNodeContents(document.querySelector("#install-command"));
      selection.removeAllRanges();
      selection.addRange(range);
    }
  });
}
