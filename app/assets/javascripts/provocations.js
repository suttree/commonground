(() => {
  // Reuse the normal Rails forms and redirects; only replace the question card.
  if (!window.fetch || !window.FormData || !window.AbortController) return;
  let pending = false;

  async function updateCard(card, url, options, successMessage) {
    if (pending) return;
    pending = true;
    const feedback = card.querySelector('.provocation-feedback');
    const buttons = Array.from(card.querySelectorAll('button'));
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 15000);
    card.setAttribute('aria-busy', 'true');
    buttons.forEach(button => { button.disabled = true; });
    feedback.textContent = options.method === 'POST' ? 'Saving answer…' : 'Loading question…';

    try {
      const response = await fetch(url, {
        ...options,
        credentials: 'same-origin',
        headers: { Accept: 'text/html' },
        signal: controller.signal
      });
      const destination = new URL(response.url);
      if (destination.origin !== window.location.origin) throw new Error('Unexpected destination');
      if (destination.pathname === '/login') {
        window.location.assign(response.url);
        return;
      }
      if (!response.ok) throw new Error('Request failed');
      const page = new DOMParser().parseFromString(await response.text(), 'text/html');
      const nextCard = page.getElementById('provocations');
      if (!nextCard || nextCard.dataset.profileId !== card.dataset.profileId || page.querySelector('.error-summary')) {
        throw new Error('Question could not be refreshed');
      }
      // Refresh the form's CSRF token too: it is part of the server-rendered card.
      card.replaceWith(nextCard);
      nextCard.focus({ preventScroll: true });
      requestAnimationFrame(() => {
        nextCard.querySelector('.provocation-feedback').textContent = successMessage;
      });
    } catch (_) {
      feedback.textContent = options.method === 'POST'
        ? "Couldn't confirm your answer. Try again or reload the page to check."
        : "Couldn't load the next question. Try again or reload the page.";
    } finally {
      clearTimeout(timeout);
      pending = false;
      card.removeAttribute('aria-busy');
      buttons.forEach(button => { button.disabled = false; });
    }
  }

  document.addEventListener('submit', event => {
    const form = event.target.closest('#provocations form.provocation-form');
    if (!form || !event.submitter?.name) return;
    event.preventDefault();
    if (pending) return;
    const body = new FormData(form);
    body.append(event.submitter.name, event.submitter.value);
    updateCard(form.closest('#provocations'), form.action, { method: 'POST', body }, 'Answer saved.');
  });

  document.addEventListener('click', event => {
    const link = event.target.closest('#provocations a[data-provocation-skip]');
    if (!link || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    if (pending) return;
    updateCard(link.closest('#provocations'), link.href, { method: 'GET' }, 'Next question.');
  });
})();
