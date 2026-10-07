// A tiny element builder, so specimens read like markup.

export type Child = Node | string | number | null | undefined | false | Child[];
type Props = Record<string, unknown> | null;

function apply(el: Element, props: Props) {
  for (const [key, value] of Object.entries(props ?? {})) {
    if (value === undefined || value === null || value === false) continue;
    if (key.startsWith("on") && typeof value === "function") {
      el.addEventListener(key.slice(2).toLowerCase(), value as EventListener);
    } else if (key === "style" && typeof value === "object") {
      for (const [prop, v] of Object.entries(value as Record<string, string | number>)) {
        (el as HTMLElement).style.setProperty(prop.startsWith("--") ? prop : prop.replace(/[A-Z]/g, (c) => `-${c.toLowerCase()}`), String(v));
      }
    } else if (key === "html") {
      el.innerHTML = String(value);
    } else {
      el.setAttribute(key === "className" ? "class" : key, value === true ? "" : String(value));
    }
  }
}

function append(el: Element, children: Child[]) {
  for (const child of children.flat(Infinity as 1) as Child[]) {
    if (child === null || child === undefined || child === false) continue;
    el.append(child instanceof Node ? child : String(child));
  }
}

export function h<K extends keyof HTMLElementTagNameMap>(tag: K, props?: Props, ...children: Child[]): HTMLElementTagNameMap[K] {
  const el = document.createElement(tag);
  apply(el, props ?? null);
  append(el, children);
  return el;
}

export function s<K extends keyof SVGElementTagNameMap>(tag: K, props?: Props, ...children: Child[]): SVGElementTagNameMap[K] {
  const el = document.createElementNS("http://www.w3.org/2000/svg", tag);
  apply(el, props ?? null);
  append(el, children);
  return el;
}

/** An icon from the shared sprite. */
export const icon = (id: string, size = 16) =>
  s("svg", { class: "i", width: size, height: size }, s("use", { href: `#${id}` }));
