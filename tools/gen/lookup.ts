// How KDE looks an icon up by name inside one theme, before it asks the next
// (KIconLoader's findMatchingIcon in kiconthemes, read 2026-11-18). It matters
// to a theme that sits over Breeze and draws only some icons: a name the theme
// lacks is shortened word by word and tried again in the same theme, so
// having "folder" answers for Breeze's "folder-new", and having
// "audio-x-generic" would answer for "audio-volume-high".

/** shared-mime-info's top-level types: a name shortened to one of these is
 *  tried once more as "<type>-x-generic". */
const mediaTypes = new Set(["text", "application", "image", "audio", "inode", "video", "message", "model", "multipart", "x-content", "x-epoc"]);

/** The name a theme answers `name` with, given which names it has; null when
 *  the next theme gets asked. */
export function kdeFinds(name: string, has: (name: string) => boolean): string | null {
  let generic = name.endsWith("-x-generic");
  const symbolic = name.endsWith("-symbolic");
  let current = name;
  while (current !== "") {
    if (has(current)) return current;
    if (generic) break;
    if (symbolic) {
      // "a-b-symbolic": plain "a-b" will do before "a-symbolic" is tried.
      current = current.slice(0, -"-symbolic".length);
      if (has(current)) return current;
    }
    const cut = current.lastIndexOf("-");
    if (cut > 1) {
      current = current.slice(0, cut);
      if (current.endsWith("-x")) current = current.slice(0, -2);
      if (symbolic) current += "-symbolic";
    } else if (mediaTypes.has(current)) {
      current += "-x-generic";
      generic = true;
    } else break;
  }
  return null;
}

/** The names of `theirs` (the theme underneath) that `ours` would answer with
 *  an icon of another name: what a drawn name takes over without meaning to. */
export function shadowed(ours: Set<string>, theirs: Iterable<string>): [string, string][] {
  const taken: [string, string][] = [];
  for (const name of theirs) {
    const found = kdeFinds(name, (n) => ours.has(n));
    if (found !== null && found !== name) taken.push([name, found]);
  }
  return taken;
}
