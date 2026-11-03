(() => {
  // Small screens collapse the signed-in links behind a disclosure button.
  const toggle = document.querySelector("[data-nav-toggle]");
  if (!toggle) return;
  const header = toggle.closest(".site-header");
  const menu = document.getElementById(toggle.getAttribute("aria-controls"));
  const setOpen = (open, { returnFocus = false } = {}) => {
    toggle.setAttribute("aria-expanded", String(open));
    header.classList.toggle("menu-open", open);
    if (!open && returnFocus) toggle.focus();
  };
  header.classList.add("has-menu-toggle");
  toggle.hidden = false;
  toggle.addEventListener("click", () => setOpen(toggle.getAttribute("aria-expanded") !== "true"));
  header.addEventListener("keydown", (event) => {
    if (event.key !== "Escape" || toggle.getAttribute("aria-expanded") !== "true") return;
    event.preventDefault();
    setOpen(false, { returnFocus: true });
  });
  // Close when focus or a tap moves elsewhere on the page.
  header.addEventListener("focusout", (event) => {
    if (event.relatedTarget && !header.contains(event.relatedTarget)) setOpen(false);
  });
  document.addEventListener("click", (event) => {
    if (!header.contains(event.target)) setOpen(false);
  });
  menu.addEventListener("click", (event) => {
    if (event.target.closest("a")) setOpen(false);
  });
  window.matchMedia("(min-width: 761px)").addEventListener("change", (event) => {
    if (event.matches) setOpen(false);
  });
  window.addEventListener("pageshow", () => setOpen(false));
})();
