(() => {
  document.querySelectorAll("[data-profile-photo]").forEach((field) => {
    const input = field.querySelector("input[type=file]");
    const preview = field.querySelector("img");
    const remove = field.querySelector("input[type=checkbox]");
    const savedSource = field.dataset.retainedSrc;
    const savedAlt = preview.alt;
    let reader;
    const releasePreview = () => {
      if (reader?.readyState === FileReader.LOADING) reader.abort();
    };
    input.addEventListener("change", () => {
      releasePreview();
      const file = input.files[0];
      if (file && file.size <= 2 * 1024 * 1024 && ["image/jpeg", "image/png", "image/webp"].includes(file.type)) {
        if (remove) remove.checked = false;
        reader = new FileReader();
        reader.addEventListener("load", () => {
          preview.src = reader.result;
          preview.alt = "Selected profile photo preview";
        });
        reader.readAsDataURL(file);
      } else {
        preview.src = remove?.checked ? field.dataset.defaultSrc : savedSource;
        preview.alt = savedAlt;
      }
    });
    remove?.addEventListener("change", () => {
      releasePreview();
      input.value = "";
      preview.src = remove.checked ? field.dataset.defaultSrc : savedSource;
      preview.alt = remove.checked ? "Default profile picture" : savedAlt;
    });
    window.addEventListener("pagehide", releasePreview);
  });
})();
