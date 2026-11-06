// Mobile menu: a vanilla stand-in for Bullet Train's mobile-menu Stimulus controller.
document.addEventListener("DOMContentLoaded", () => {
  const menu = document.getElementById("mobile-menu");
  if (!menu) return;

  const open = () => menu.classList.remove("hidden");
  const close = () => menu.classList.add("hidden");

  document.querySelectorAll("[data-menu-open]").forEach((el) => el.addEventListener("click", open));
  document.querySelectorAll("[data-menu-close]").forEach((el) => el.addEventListener("click", close));
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") close();
  });
});
