import { youtubeIdFromUrl } from "./youtube";

export function youtubeDialogFor(
  templateId: string,
  onSubmit: (videoId: string) => void,
  onCancel: () => void,
): HTMLDialogElement {
  const template = document.getElementById(templateId);
  if (!(template instanceof HTMLTemplateElement)) {
    throw new Error(`Missing Lexical YouTube dialog template: ${templateId}`);
  }

  const element = template.content.firstElementChild?.cloneNode(true);
  if (!(element instanceof HTMLDialogElement)) {
    throw new Error(`Invalid Lexical YouTube dialog template: ${templateId}`);
  }

  const dialog = element;
  const form = dialog.querySelector("form");
  const input = dialog.querySelector("[data-youtube-input]");
  const error = dialog.querySelector("[data-youtube-error]");
  const cancel = dialog.querySelector("[data-youtube-cancel]");

  if (!(form instanceof HTMLFormElement)) {
    throw new Error(`Missing YouTube dialog form: ${templateId}`);
  }

  if (!(input instanceof HTMLInputElement)) {
    throw new Error(`Missing YouTube dialog input: ${templateId}`);
  }

  if (!(error instanceof HTMLElement)) {
    throw new Error(`Missing YouTube dialog error element: ${templateId}`);
  }

  if (!(cancel instanceof HTMLButtonElement)) {
    throw new Error(`Missing YouTube dialog cancel button: ${templateId}`);
  }

  cancel.addEventListener("click", () => dialog.close());

  form.addEventListener("submit", (event) => {
    event.preventDefault();

    const id = youtubeIdFromUrl(input.value);
    if (!id) {
      error.textContent = "Enter a valid YouTube URL.";
      error.hidden = false;
      return;
    }

    error.hidden = true;
    onSubmit(id);
    input.value = "";
    dialog.returnValue = "inserted";
    dialog.close();
  });

  dialog.addEventListener("close", () => {
    error.hidden = true;
    if (dialog.returnValue !== "inserted") onCancel();
    dialog.returnValue = "";
  });

  return dialog;
}

export function openYoutubeDialog(dialog: HTMLDialogElement): void {
  if (!dialog.open) dialog.showModal();

  const input = dialog.querySelector("input");
  if (input instanceof HTMLInputElement) {
    requestAnimationFrame(() => input.focus());
  }
}
