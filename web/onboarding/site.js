document.addEventListener('DOMContentLoaded', () => {
  const reveals = document.querySelectorAll('[data-reveal]');
  reveals.forEach((item, index) => {
    const delay = 0.08 * index + 0.1;
    item.style.animationDelay = `${delay}s`;
  });
});
