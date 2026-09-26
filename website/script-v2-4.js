const root = document.documentElement;
const body = document.body;
const header = document.querySelector('.site-header');
const progress = document.querySelector('.page-progress span');
const navToggle = document.querySelector('.nav-toggle');
const navLinks = [...document.querySelectorAll('.nav a[href^="#"]')];
const sections = [...document.querySelectorAll('[data-section]')];
const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

window.addEventListener('DOMContentLoaded', () => {
  requestAnimationFrame(() => body.classList.add('loaded'));
});

function updateScrollEffects() {
  const y = window.scrollY;
  const max = Math.max(1, document.documentElement.scrollHeight - window.innerHeight);
  if (progress) progress.style.transform = `scaleX(${Math.min(1, y / max)})`;
  header?.classList.toggle('scrolled', y > 24);

  if (!prefersReducedMotion && y < window.innerHeight * 1.2) {
    root.style.setProperty('--hero-y', `${Math.min(34, y * 0.03)}px`);
  }
}

window.addEventListener('scroll', updateScrollEffects, { passive: true });
updateScrollEffects();

if (!prefersReducedMotion) {
  window.addEventListener('pointermove', (event) => {
    if (window.scrollY > window.innerHeight * 1.1) return;
    const x = ((event.clientX / window.innerWidth) - 0.5) * -14;
    const y = ((event.clientY / window.innerHeight) - 0.5) * -10 + Math.min(34, window.scrollY * 0.03);
    root.style.setProperty('--hero-x', `${x}px`);
    root.style.setProperty('--hero-y', `${y}px`);
  }, { passive: true });
}

const revealObserver = new IntersectionObserver((entries) => {
  entries.forEach((entry) => {
    if (entry.isIntersecting) {
      entry.target.classList.add('visible');
      revealObserver.unobserve(entry.target);
    }
  });
}, { threshold: 0.12, rootMargin: '0px 0px -6% 0px' });

document.querySelectorAll('.reveal').forEach((el) => revealObserver.observe(el));

const sectionObserver = new IntersectionObserver((entries) => {
  const visible = entries
    .filter((entry) => entry.isIntersecting)
    .sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];

  if (!visible) return;
  const id = visible.target.id;
  navLinks.forEach((link) => link.classList.toggle('active', link.getAttribute('href') === `#${id}`));
}, { threshold: [0.25, 0.5, 0.75], rootMargin: '-20% 0px -55% 0px' });

sections.filter((section) => section.id).forEach((section) => sectionObserver.observe(section));

navToggle?.addEventListener('click', () => {
  const open = body.classList.toggle('nav-open');
  navToggle.setAttribute('aria-expanded', String(open));
});

navLinks.forEach((link) => link.addEventListener('click', () => {
  body.classList.remove('nav-open');
  navToggle?.setAttribute('aria-expanded', 'false');
}));

document.querySelectorAll('.copy').forEach((button) => {
  button.addEventListener('click', async () => {
    const text = (button.dataset.copy || '').replace(/\\n/g, '\n');
    const original = button.textContent;
    try {
      await navigator.clipboard.writeText(text);
      button.textContent = 'COPIED';
      button.classList.add('copied');
    } catch {
      button.textContent = 'SELECT';
    }
    setTimeout(() => {
      button.textContent = original;
      button.classList.remove('copied');
    }, 1400);
  });
});

const lightbox = document.querySelector('.lightbox');
let previousFocus = null;

if (lightbox) {
  const lightboxImage = lightbox.querySelector('img');
  const lightboxCaption = lightbox.querySelector('p');
  const lightboxClose = lightbox.querySelector('.lightbox-close');

  function openLightbox(target) {
    previousFocus = document.activeElement;
    lightboxImage.src = target.dataset.lightbox;
    lightboxCaption.textContent = target.dataset.caption || '';
    lightbox.classList.add('open');
    lightbox.setAttribute('aria-hidden', 'false');
    body.style.overflow = 'hidden';
    lightboxClose?.focus();
  }

  function closeLightbox() {
    lightbox.classList.remove('open');
    lightbox.setAttribute('aria-hidden', 'true');
    body.style.overflow = '';
    lightboxImage.src = '';
    previousFocus?.focus?.();
  }

  document.querySelectorAll('.lightbox-target').forEach((target) => {
    target.addEventListener('click', () => openLightbox(target));
    target.addEventListener('keydown', (event) => {
      if (event.key === 'Enter' || event.key === ' ') {
        event.preventDefault();
        openLightbox(target);
      }
    });
  });

  lightboxClose?.addEventListener('click', closeLightbox);
  lightbox.addEventListener('click', (event) => {
    if (event.target === lightbox) closeLightbox();
  });
  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && lightbox.classList.contains('open')) closeLightbox();
  });
}

// V2.3 — "How does it work?" architecture explainer
const howModal = document.querySelector('.how-modal');
const howOpeners = document.querySelectorAll('[data-how-open]');
const howClosers = document.querySelectorAll('[data-how-close]');
let howPreviousFocus = null;

function openHowModal() {
  if (!howModal) return;
  howPreviousFocus = document.activeElement;
  howModal.classList.add('open');
  howModal.setAttribute('aria-hidden', 'false');
  body.style.overflow = 'hidden';
  howModal.querySelector('.how-modal-close')?.focus();
}

function closeHowModal() {
  if (!howModal) return;
  howModal.classList.remove('open');
  howModal.setAttribute('aria-hidden', 'true');
  body.style.overflow = '';
  howPreviousFocus?.focus?.();
}

howOpeners.forEach((button) => button.addEventListener('click', openHowModal));
howClosers.forEach((button) => button.addEventListener('click', closeHowModal));
document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape' && howModal?.classList.contains('open')) closeHowModal();
});
