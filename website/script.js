const copyButtons = document.querySelectorAll('.copy');

copyButtons.forEach((button) => {
  button.addEventListener('click', async () => {
    const text = button.dataset.copy || '';
    try {
      await navigator.clipboard.writeText(text);
      const previous = button.textContent;
      button.textContent = 'Copied';
      setTimeout(() => { button.textContent = previous; }, 1400);
    } catch {
      button.textContent = 'Select';
      setTimeout(() => { button.textContent = 'Copy'; }, 1400);
    }
  });
});
