type TelegramLoginHook = {
  el: HTMLElement;
};

export const TelegramLogin = {
  mounted(this: TelegramLoginHook) {
    if (this.el.dataset.inited === "1") return;
    this.el.dataset.inited = "1";

    const botUsername = this.el.dataset.botUsername;
    if (!botUsername) throw new Error("Missing Telegram bot username");

    const requestAccess = this.el.dataset.requestAccess || "write";
    const size = this.el.dataset.size || "large";
    const returnTo = `${window.location.pathname}${window.location.search || ""}`;
    const authUrl = `/auth/telegram/callback?return_to=${encodeURIComponent(returnTo)}`;

    const script = document.createElement("script");
    script.async = true;
    script.src = "https://telegram.org/js/telegram-widget.js?22";
    script.dataset.telegramLogin = botUsername;
    script.dataset.authUrl = authUrl;
    script.dataset.requestAccess = requestAccess;
    script.dataset.size = size;

    this.el.appendChild(script);
  },
};
