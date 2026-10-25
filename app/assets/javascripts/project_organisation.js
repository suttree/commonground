(() => {
  document.querySelectorAll('[data-project-organisation]').forEach((field) => {
    const select = field.querySelector('select');
    const search = field.querySelector('input[type=search]');
    const options = Array.from(select.options).map((option) => option.cloneNode(true));
    const newCompany = field.querySelector('[data-new-company]');
    const name = newCompany.querySelector('input');
    const results = field.querySelector('[data-company-results]');
    field.querySelector('[data-company-search]').hidden = false;

    const update = () => {
      const selected = select.value;
      const term = search.value.trim().toLocaleLowerCase();
      const matches = options.filter((option) => option.value && option.textContent.toLocaleLowerCase().includes(term));
      const visible = options.filter((option) => !option.value || option.value === selected || matches.includes(option));
      select.replaceChildren(...visible.map((option) => option.cloneNode(true)));
      select.value = selected;
      select.size = term ? Math.min(6, Math.max(2, visible.length)) : 1;
      results.textContent = term ? `${matches.length} matching ${matches.length === 1 ? 'company' : 'companies'}.` : '';
      newCompany.hidden = Boolean(selected);
      name.disabled = Boolean(selected);
    };
    search.addEventListener('input', update);
    select.addEventListener('change', update);
    update();
  });
})();
