(() => {
  document.querySelectorAll('[data-project-organisation]').forEach((field) => {
    const select = field.querySelector('select');
    const newCompany = field.querySelector('[data-new-company]');
    const name = newCompany.querySelector('input');
    const update = () => {
      newCompany.hidden = Boolean(select.value);
      name.disabled = Boolean(select.value);
    };
    select.addEventListener('change', update);
    update();
  });
})();
