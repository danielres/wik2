import { youtubeIdFromUrl } from "./youtube";

export function youtubeDialogFor(
  onSubmit: (videoId: string) => void,
  onCancel: () => void,
): HTMLDialogElement {
  const dialog = document.createElement("dialog");
  dialog.className = "LEXICAL_YOUTUBE_DIALOG";

  const form = document.createElement("form");
  form.method = "dialog";
  form.className = "LEXICAL_YOUTUBE_FORM";

  const title = document.createElement("div");
  title.className = "LEXICAL_YOUTUBE_TITLE";
  title.textContent = "YouTube embed";

  const input = document.createElement("input");
  input.type = "text";
  input.required = true;
  input.placeholder = "https://www.youtube.com/watch?v=W-hwnJUT854";
  input.className = "LEXICAL_YOUTUBE_INPUT";

  const error = document.createElement("div");
  error.className = "LEXICAL_YOUTUBE_ERROR";
  error.hidden = true;

  const actions = document.createElement("div");
  actions.className = "LEXICAL_YOUTUBE_ACTIONS";

  const cancel = document.createElement("button");
  cancel.type = "button";
  cancel.className = "LEXICAL_YOUTUBE_BUTTON secondary";
  cancel.textContent = "Cancel";
  cancel.addEventListener("click", () => dialog.close());

  const submit = document.createElement("button");
  submit.type = "submit";
  submit.className = "LEXICAL_YOUTUBE_BUTTON primary";
  submit.textContent = "Insert";

  actions.append(cancel, submit);
  form.append(title, input, error, actions);
  dialog.append(form);

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
