type FloatingPlacement = "bottom" | "top";

type PositionFloatingOptions = {
  anchorRect: DOMRect;
  floating: HTMLElement;
  offset?: number;
  preferredPlacement?: FloatingPlacement;
  viewportPadding?: number;
};

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

function choosePlacement(
  anchorRect: DOMRect,
  floatingHeight: number,
  preferredPlacement: FloatingPlacement,
  offset: number,
): FloatingPlacement {
  const spaceAbove = anchorRect.top;
  const spaceBelow = window.innerHeight - anchorRect.bottom;
  const neededSpace = floatingHeight + offset;

  if (preferredPlacement === "top") {
    return spaceAbove >= neededSpace || spaceAbove >= spaceBelow ? "top" : "bottom";
  }

  return spaceBelow >= neededSpace || spaceBelow >= spaceAbove ? "bottom" : "top";
}

export function positionFloating({
  anchorRect,
  floating,
  offset = 8,
  preferredPlacement = "bottom",
  viewportPadding = 8,
}: PositionFloatingOptions): void {
  floating.hidden = false;
  floating.style.left = "0px";
  floating.style.top = "0px";

  const floatingRect = floating.getBoundingClientRect();
  const maxLeft = Math.max(viewportPadding, window.innerWidth - floatingRect.width - viewportPadding);
  const maxTop = Math.max(viewportPadding, window.innerHeight - floatingRect.height - viewportPadding);
  const left = clamp(
    anchorRect.left + anchorRect.width / 2 - floatingRect.width / 2,
    viewportPadding,
    maxLeft,
  );
  const placement = choosePlacement(
    anchorRect,
    floatingRect.height,
    preferredPlacement,
    offset,
  );
  const requestedTop =
    placement === "top"
      ? anchorRect.top - floatingRect.height - offset
      : anchorRect.bottom + offset;
  const top = clamp(requestedTop, viewportPadding, maxTop);

  floating.dataset.placement = placement;
  floating.style.left = `${left}px`;
  floating.style.top = `${top}px`;
}
