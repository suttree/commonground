(() => {
  document.querySelectorAll('[data-company-wizard]').forEach((form) => {
    const steps = Array.from(form.querySelectorAll('[data-company-step]'));
    const progress = form.querySelector('[data-company-progress]');
    const status = form.querySelector('[data-company-status]');
    const position = form.querySelector('[data-company-step-value]');
    const back = form.querySelector('[data-company-back]');
    const next = form.querySelector('[data-company-next]');
    const submit = form.querySelector('[data-company-submit]');
    const errors = form.parentElement.querySelector('.error-summary');
    let current = Math.min(steps.length - 1, Math.max(0, Number(position.value) || 0));

    const show = (index, focus = true) => {
      current = index;
      position.value = index;
      steps.forEach((step, i) => { step.hidden = i !== index; });
      progress.querySelectorAll('li').forEach((item, i) => {
        if (i === index) item.setAttribute('aria-current', 'step');
        else item.removeAttribute('aria-current');
        item.classList.toggle('is-complete', i < index);
      });
      status.textContent = `Step ${index + 1} of ${steps.length}: ${steps[index].dataset.companyStep}`;
      back.hidden = index === 0;
      next.hidden = index === steps.length - 1;
      submit.hidden = index !== steps.length - 1;
      if (focus) {
        steps[index].focus({ preventScroll: true });
        progress.scrollIntoView({ block: 'start' });
      }
    };

    const validate = (step) => {
      const invalid = Array.from(step.querySelectorAll('input, textarea, select'))
        .find((field) => field.willValidate && !field.validity.valid);
      if (!invalid) return true;
      show(steps.indexOf(step), false);
      invalid.reportValidity();
      return false;
    };

    back.addEventListener('click', () => show(current - 1));
    next.addEventListener('click', () => {
      if (validate(steps[current])) show(current + 1);
    });
    form.addEventListener('keydown', (event) => {
      if (event.key !== 'Enter' || event.isComposing || !event.target.matches('input[type="text"], input[type="email"], input[type="url"]')) return;
      event.preventDefault();
      form.requestSubmit(submit);
    });
    form.addEventListener('submit', (event) => {
      // Repeater buttons post all answers and return to this step without creating a profile.
      if (event.submitter?.name === 'add_section') return;
      if (current < steps.length - 1) {
        event.preventDefault();
        if (validate(steps[current])) show(current + 1);
      } else if (!steps.every(validate)) {
        event.preventDefault();
      }
    });

    const errorTargets = Array.from(errors?.querySelectorAll('a[href^="#"]') || [])
      .map((link) => document.getElementById(link.hash.slice(1))).filter(Boolean);
    const errorStep = steps.findIndex((step) => errorTargets.some((target) => step.contains(target)));
    if (errorStep >= 0) current = errorStep;
    errors?.addEventListener('click', (event) => {
      const link = event.target.closest('a[href^="#"]');
      if (!link) return;
      const target = document.getElementById(link.hash.slice(1));
      const index = steps.findIndex((step) => step.contains(target));
      if (index < 0) return;
      event.preventDefault();
      show(index, false);
      const details = target.closest('details');
      if (details) details.open = true;
      target.focus();
      target.scrollIntoView({ block: 'center' });
    });

    form.noValidate = true;
    progress.hidden = false;
    show(current, false);
  });
})();
