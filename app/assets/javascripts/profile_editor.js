(() => {
  const form = document.querySelector("form[data-profile-editor]");
  if (!form) return;
  let dirty = form.dataset.unsaved === "true";
  let submitting = false;
  form.addEventListener("input", () => { dirty = true; });
  form.addEventListener("change", () => { dirty = true; });
  form.addEventListener("submit", () => { submitting = true; });
  const warning = document.getElementById("profile-unsaved");
  let destination;
  document.querySelectorAll(".profile-tabs a").forEach((link) => {
    link.addEventListener("click", (event) => {
      if (!dirty || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
      event.preventDefault();
      destination = link.href;
      warning.hidden = false;
      warning.focus();
    });
  });
  document.getElementById("profile-keep-editing").addEventListener("click", () => {
    warning.hidden = true;
    form.querySelector("input:not([type=hidden]), textarea, select, button")?.focus();
  });
  document.getElementById("profile-discard").addEventListener("click", () => {
    if (!destination) return;
    submitting = true;
    window.location.assign(destination);
  });
  window.addEventListener("pageshow", () => { submitting = false; });
  window.addEventListener("beforeunload", (event) => {
    if (!dirty || submitting) return;
    event.preventDefault();
    event.returnValue = "";
  });
})();
