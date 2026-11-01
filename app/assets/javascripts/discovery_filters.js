(() => {
  const sheet = document.querySelector('[data-filter-sheet]');
  const isSheet = () => sheet?.matches(':modal');

  // The desktop sidebar applies a choice at once; the small-screen sheet waits for Apply.
  document.querySelectorAll('[data-auto-submit]').forEach((select) => {
    select.addEventListener('change', () => { if (!isSheet()) select.form.requestSubmit(); });
  });

  if (!sheet || typeof sheet.showModal !== 'function') return;
  const openButton = document.querySelector('[data-filter-open]');
  const small = window.matchMedia('(max-width: 650px)');
  const root = document.documentElement;
  let modal = false;

  const close = () => { if (sheet.open) sheet.close(); };
  const sync = () => {
    openButton.hidden = !small.matches;
    if (small.matches) {
      if (sheet.open && !isSheet()) sheet.close();
    } else {
      if (isSheet()) sheet.close();
      if (!sheet.open) sheet.show();
    }
  };

  openButton.addEventListener('click', () => {
    if (sheet.open) sheet.close();
    sheet.showModal();
    modal = true;
    root.classList.add('sheet-open');
  });
  sheet.querySelector('[data-filter-close]').addEventListener('click', close);
  // A tap on the backdrop (outside the sheet's box) closes it, like Escape.
  sheet.addEventListener('click', (event) => {
    if (event.target !== sheet) return;
    const box = sheet.getBoundingClientRect();
    const inside = event.clientX >= box.left && event.clientX <= box.right && event.clientY >= box.top && event.clientY <= box.bottom;
    if (!inside) close();
  });
  sheet.addEventListener('close', () => {
    root.classList.remove('sheet-open');
    if (modal && small.matches) openButton.focus();
    modal = false;
  });
  small.addEventListener('change', sync);
  // Returning with the back button should show results, not a sheet left open.
  window.addEventListener('pageshow', () => { if (isSheet()) close(); sync(); });
  sync();
})();
