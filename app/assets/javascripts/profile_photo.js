(() => {
  document.querySelectorAll("[data-profile-photo]").forEach((field) => {
    const input = field.querySelector("input[type=file]");
    const preview = field.querySelector("img");
    const remove = field.querySelector("input[type=checkbox]");
    const savedSource = field.dataset.retainedSrc;
    const savedAlt = preview.alt;
    const editorial = field.hasAttribute("data-editorial-photo");
    const photoLabel = field.querySelector(".story-photo-label");
    const updateEditorial = (hasPhoto) => {
      if (!editorial) return;
      preview.hidden = !hasPhoto;
      photoLabel.textContent = hasPhoto ? "Edit photo" : "＋ Add photo";
    };
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
          updateEditorial(true);
        });
        reader.readAsDataURL(file);
      } else {
        preview.src = remove?.checked ? field.dataset.defaultSrc : savedSource;
        preview.alt = savedAlt;
        updateEditorial(!remove?.checked && field.dataset.hasPhoto === "true");
      }
    });
    remove?.addEventListener("change", () => {
      releasePreview();
      input.value = "";
      preview.src = remove.checked ? field.dataset.defaultSrc : savedSource;
      preview.alt = remove.checked ? "Commonbound logo" : savedAlt;
      updateEditorial(!remove.checked);
    });
    window.addEventListener("pagehide", releasePreview);
  });
})();
