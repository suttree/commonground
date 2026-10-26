(() => {
  document.querySelectorAll('[data-collaborator-picker]').forEach((picker) => {
    const form = picker.closest('form');
    const query = picker.querySelector('input[type=search]');
    const results = picker.querySelector('#collaborator-results');
    const selected = picker.querySelector('[data-selected-collaborators]');
    const status = picker.querySelector('[data-collaborator-status]');
    const hint = picker.querySelector('[data-selected-hint]');
    const searchButton = picker.querySelector('[data-search-collaborators]');
    let timer;
    let request;
    let generation = 0;
    const ids = () => new Set(Array.from(selected.querySelectorAll('input'), (input) => input.value));
    const refreshHint = () => { hint.textContent = `${ids().size} of 20 collaborators selected. Save the project to apply changes.`; };
    const prepareSelected = (row) => {
      row.querySelector('input').type = 'hidden';
      let remove = row.querySelector('[data-remove-collaborator]');
      if (!remove) {
        remove = document.createElement('button');
        remove.type = 'button';
        remove.textContent = 'Remove';
        row.append(remove);
      }
      remove.hidden = false;
      remove.className = 'button secondary';
      remove.setAttribute('aria-label', `Remove ${row.querySelector('label').textContent.trim()}`);
      remove.addEventListener('click', () => { row.remove(); refreshHint(); query.focus(); search(); });
    };
    selected.querySelectorAll('[data-collaborator-id]').forEach(prepareSelected);
    refreshHint();
    const search = async () => {
      clearTimeout(timer);
      request?.abort();
      const version = ++generation;
      results.replaceChildren();
      if (query.value.trim().length < 2) {
        status.textContent = 'Type at least two letters to search.';
        return;
      }
      request = new AbortController();
      status.textContent = 'Searching…';
      const url = new URL(picker.dataset.searchUrl, window.location.origin);
      url.searchParams.set('collaborator_query', query.value.trim());
      url.searchParams.set('submission_id', form.querySelector('[name="challenge[submission_id]"]').value);
      try {
        const response = await fetch(url, { signal: request.signal, headers: { Accept: 'application/json' } });
        if (!response.ok || response.redirected) throw new Error('Search failed');
        const members = await response.json();
        if (generation !== version) return;
        const available = members.filter((member) => !ids().has(String(member.id)));
        status.textContent = available.length ? 'Choose Add beside a name. Showing up to 10 matches.' : 'No new matches. Try another name or invite someone by email.';
        available.forEach((member) => {
          const row = document.createElement('div');
          row.className = 'collaborator-search-result';
          const label = document.createElement('span');
          label.textContent = [member.name, member.location].filter(Boolean).join(' · ');
          const add = document.createElement('button');
          add.type = 'button';
          add.className = 'button secondary';
          add.textContent = 'Add';
          add.setAttribute('aria-label', `Add ${member.name}`);
          add.addEventListener('click', () => {
            if (ids().size >= 20) { status.textContent = 'You can add up to 20 collaborators. Remove someone before adding another.'; return; }
            if (ids().has(String(member.id))) return;
            const item = document.createElement('div');
            item.className = 'check-choice';
            item.dataset.collaboratorId = member.id;
            const input = document.createElement('input');
            input.type = 'checkbox'; input.name = 'challenge[collaborator_ids][]'; input.value = member.id; input.checked = true;
            input.id = `challenge_collaborator_${member.id}`;
            const name = document.createElement('label');
            name.htmlFor = input.id; name.textContent = member.name;
            item.append(input, name); selected.append(item); prepareSelected(item); refreshHint();
            row.remove(); status.textContent = `${member.name} added. Save the project to apply changes.`;
            item.querySelector('button').focus();
          });
          row.append(label, add); results.append(row);
        });
      } catch (error) {
        if (error.name !== 'AbortError' && generation === version) status.textContent = 'Search could not load. Try again, or use the email invitation below.';
      }
    };
    query.addEventListener('input', () => { request?.abort(); generation++; results.replaceChildren(); clearTimeout(timer); timer = setTimeout(search, 250); });
    query.addEventListener('keydown', (event) => { if (event.key === 'Enter') { event.preventDefault(); search(); } });
    searchButton.addEventListener('click', (event) => { event.preventDefault(); search(); });
    form.querySelector('[name="challenge[submission_id]"]').addEventListener('change', search);
    if (query.value.trim().length >= 2) search();
  });
})();
