(() => {
  const form = document.querySelector("form[data-profile-editor]");
  if (!form) return;
  const warning = document.getElementById("profile-unsaved");
  const initial = () => JSON.stringify([...new FormData(form)].filter(([key]) => !["authenticity_token", "next_section"].includes(key)).map(([key, value]) => [key, value instanceof File ? [value.name, value.size, value.name ? value.lastModified : 0] : value]));
  const baseline = initial();
  let dirty = form.dataset.unsaved === "true";
  let submitting = false;
  let destination;
  let pendingForm;
  const buttons = [...form.querySelectorAll("[data-save-button]")];
  const setText = (button, text) => { if (button.tagName === "INPUT") button.value = text; else button.textContent = text; };
  const render = () => {
    const text = submitting ? "Saving your changes…" : dirty ? "Unsaved changes" : form.dataset.savedMessage || "No unsaved changes";
    form.querySelectorAll("[data-save-label]").forEach(el => { el.textContent = text; });
    form.querySelectorAll("[data-save-note]").forEach(el => { el.textContent = submitting ? "Keep this page open until saving finishes." : dirty ? "Not published yet. Save to update your profile." : "Edits are published only when you save."; });
    form.querySelectorAll("[data-save-state]").forEach(el => { el.classList.toggle("is-dirty", dirty); });
    buttons.forEach(button => { button.disabled = submitting || !dirty; setText(button, submitting ? "Saving…" : dirty ? "Save changes" : "✓ Saved"); });
  };
  const changed = () => {
    dirty = form.dataset.unsaved === "true" || initial() !== baseline;
    const availability = form.querySelector("#submission_availability_status");
    if (availability) {
      form.querySelector("[data-availability-dot]")?.classList.toggle("is-open", ["Open to a new project", "Available for occasional help"].includes(availability.value));
      const label = form.querySelector("[data-availability-label]");
      if (label) label.textContent = availability.value || "Availability not shared";
    }
    render();
  };
  form.addEventListener("input", changed);
  form.addEventListener("change", changed);
  form.addEventListener("submit", (event) => {
    if (submitting) { event.preventDefault(); return; }
    submitting = true;
    // Keep the submitter enabled: repeat-entry buttons carry name/value data.
    form.querySelectorAll("[data-save-label]").forEach(el => { el.textContent = event.submitter?.name === "add_section" ? "Adding an entry; changes are not saved yet…" : "Saving your changes…"; });
    buttons.forEach(button => setText(button, "Saving…"));
  });
  document.querySelectorAll(".profile-tabs a, .story-editor a:not([target])").forEach(link => {
    link.addEventListener("click", event => {
      const target = new URL(link.href);
      if (target.origin === location.origin && target.pathname === location.pathname && target.search === location.search && target.hash) return;
      if (!dirty || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
      event.preventDefault();
      pendingForm = null;
      destination = link.href;
      const section = new URL(link.href).searchParams.get("section");
      const next = document.getElementById("profile-next-section");
      if (next) next.value = section || "";
      const continueButton = document.getElementById("profile-save-continue");
      if (continueButton) continueButton.hidden = !link.closest(".story-nav");
      warning.hidden = false;
      warning.focus();
    });
  });
  document.querySelectorAll(".story-side-projects form").forEach(otherForm => {
    otherForm.addEventListener("submit", event => {
      if (!dirty || submitting) return;
      event.preventDefault();
      pendingForm = otherForm;
      destination = null;
      document.getElementById("profile-save-continue").hidden = true;
      warning.hidden = false;
      warning.focus();
    });
  });
  document.getElementById("profile-keep-editing")?.addEventListener("click", () => {
    warning.hidden = true;
    const next = document.getElementById("profile-next-section");
    if (next) next.value = "";
    form.querySelector("input:not([type=hidden]), textarea, select, button")?.focus();
  });
  document.getElementById("profile-discard")?.addEventListener("click", () => {
    if (!destination && !pendingForm) return;
    submitting = true;
    if (pendingForm) pendingForm.requestSubmit();
    else window.location.assign(destination);
  });
  window.addEventListener("pageshow", () => { submitting = false; render(); });
  window.addEventListener("beforeunload", event => {
    if (!dirty || submitting) return;
    event.preventDefault();
    event.returnValue = "";
  });
  render();
})();
