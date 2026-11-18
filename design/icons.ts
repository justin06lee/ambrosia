// App icons: the apps a new install starts with, each on the tile every
// Ambrosia app icon sits on (DESIGN.md › Iconography: the superellipse with
// its margin, one light from above, a soft gradient, nothing photographic).
// tools/gen builds them into the "Ambrosia" icon theme under the names those
// apps ask for, so the Dock, Search and Files show ours instead of Breeze's.
//
// Drawn by hand on a 256 grid; the tile runs from 24 to 232. Like the Dock's
// rules say: the shapes are ours, never traced from another system's icons.

export const grid = 256;
/** The tile's square on the grid: 0.805 of it, as a Mac's icons sit on theirs. */
export const tile = { at: 24, side: 208 };

export type AppIcon = {
  /** The names apps ask for it by; the first is the file, the rest link to it. */
  names: string[];
  /** The tile's gradient, top to bottom. */
  tile: [string, string];
  /** What's drawn on the tile, as SVG. */
  art: string;
};

const white = "#ffffff";
const round = `stroke-linecap="round" stroke-linejoin="round"`;

/** Rows of round keys for the calculator: the last column is the operators'. */
const keys = [122, 158, 194]
  .flatMap((y, row) =>
    [73, 110, 146, 183].map((x, column) => {
      const fill = column === 3 ? "#ff9f0a" : row === 0 ? "#a9a9af" : "#6e6e74";
      return `<circle cx="${x}" cy="${y}" r="13.5" fill="${fill}"/>`;
    }),
  )
  .join("");

/** A zip's teeth, left and right in turn, down the middle. */
const teeth = Array.from({ length: 9 }, (_, i) => {
  const y = 40 + i * 12;
  return (
    `<rect x="111" y="${y}" width="16" height="8" rx="2.5" fill="#f4f4f6"/>` +
    `<rect x="129" y="${y + 6}" width="16" height="8" rx="2.5" fill="#f4f4f6"/>`
  );
}).join("");

/** A chip's legs: three a side. */
const legs = [104, 124, 144]
  .map(
    (at) =>
      `<rect x="${at}" y="66" width="8" height="22" rx="4"/><rect x="${at}" y="168" width="8" height="22" rx="4"/>` +
      `<rect x="66" y="${at}" width="22" height="8" rx="4"/><rect x="168" y="${at}" width="22" height="8" rx="4"/>`,
  )
  .join("");

export const appIcons: Record<string, AppIcon> = {
  // A prompt and the place to type.
  terminal: {
    names: ["utilities-terminal", "org.kde.konsole", "konsole", "terminal", "utilities-x-terminal", "xterm"],
    tile: ["#4b4b50", "#1c1c1e"],
    art:
      `<path d="M70 90L110 128L70 166" fill="none" stroke="${white}" stroke-width="19" ${round}/>` +
      `<path d="M126 170H186" fill="none" stroke="${white}" stroke-width="19" ${round}/>`,
  },
  // A sheet of writing and the pencil it was written with.
  "text-editor": {
    names: ["kate", "org.kde.kate", "kwrite", "org.kde.kwrite", "accessories-text-editor", "text-editor"],
    tile: ["#ffffff", "#e6e6ea"],
    art:
      [[70, 122], [94, 106], [118, 122], [142, 84], [166, 60]]
        .map(([y, width]) => `<rect x="62" y="${y}" width="${width}" height="11" rx="5.5" fill="#c4c4ca"/>`)
        .join("") +
      `<g transform="translate(96 198) rotate(-45)">` +
      `<path d="M0 0L30 -15V15Z" fill="#f2d7a6"/><path d="M0 0L11 -5.5V5.5Z" fill="#3a3a3c"/>` +
      `<rect x="30" y="-15" width="88" height="30" fill="#ffc533"/><rect x="30" y="5" width="88" height="10" fill="#f0a31a"/>` +
      `<rect x="118" y="-15" width="13" height="30" fill="#c9c9cf"/>` +
      `<path d="M131 -15H141Q149 -15 149 -7V7Q149 15 141 15H131Z" fill="#ff8f85"/></g>`,
  },
  // A picture: sky, sun and two hills in a white frame.
  "image-viewer": {
    names: ["gwenview", "org.kde.gwenview", "image-viewer", "multimedia-photo-viewer", "eog", "org.gnome.eog"],
    tile: ["#6fd0ff", "#2b7bf2"],
    art:
      `<rect x="52" y="64" width="152" height="128" rx="16" fill="${white}"/>` +
      `<rect x="62" y="74" width="132" height="108" rx="7" fill="#a8dcff"/>` +
      `<circle cx="162" cy="104" r="13" fill="#ffd042"/>` +
      `<path d="M66 182L106 124Q110 118 114 124L140 162L152 148Q156 143 160 148L190 182Z" fill="#3f9a63"/>` +
      `<path d="M110 182L148 144Q154 138 160 144L190 176V182Z" fill="#2d7f4f"/>`,
  },
  // A page with its corner turned down.
  "document-viewer": {
    names: ["okular", "org.kde.okular", "graphics-viewer-document", "document-viewer", "evince", "org.gnome.Evince"],
    tile: ["#ff8375", "#de3628"],
    art:
      `<path d="M88 54H148L182 88V190Q182 202 170 202H88Q76 202 76 190V66Q76 54 88 54Z" fill="${white}"/>` +
      `<path d="M148 54V78Q148 88 158 88H182Z" fill="#ffc9c2"/>` +
      [112, 132, 152, 172]
        .map((y, i) => `<rect x="94" y="${y}" width="${i === 3 ? 44 : 70}" height="9" rx="4.5" fill="#f3aaa2"/>`)
        .join(""),
  },
  // A display over rows of keys.
  calculator: {
    names: ["accessories-calculator", "kcalc", "org.kde.kcalc", "calc", "org.gnome.Calculator"],
    tile: ["#56565b", "#28282a"],
    art: `<rect x="59" y="56" width="138" height="38" rx="12" fill="#dcdce1"/>` + keys,
  },
  // A zip, half done up.
  archiver: {
    names: ["ark", "org.kde.ark", "utilities-file-archiver", "file-roller", "org.gnome.FileRoller"],
    tile: ["#e6cda3", "#bf9658"],
    art:
      `<rect x="106" y="25" width="44" height="206" fill="#a67f45" opacity="0.55"/>` +
      teeth +
      `<rect x="113" y="150" width="30" height="30" rx="8" fill="#f4f4f6"/>` +
      `<rect x="123" y="174" width="10" height="18" fill="#f4f4f6"/>` +
      `<path d="M128 184a14 14 0 1 0 0.01 0ZM128 191a7 7 0 1 1 -0.01 0Z" fill="#f4f4f6" fill-rule="evenodd"/>`,
  },
  // A shopping bag, and the arrow that brings an app down.
  store: {
    names: ["plasmadiscover", "org.kde.discover", "system-software-install", "software-store", "org.gnome.Software"],
    tile: ["#52aeff", "#1766ea"],
    art:
      `<path d="M102 108V92a26 26 0 0 1 52 0V108" fill="none" stroke="${white}" stroke-width="11" ${round}/>` +
      `<path d="M74 100H182L192 194Q193 208 179 208H77Q63 208 64 194Z" fill="${white}"/>` +
      `<path d="M128 126V170M108 152L128 172L148 152" fill="none" stroke="#1d70ee" stroke-width="11" ${round}/>`,
  },
  // A viewfinder's corners round a lens.
  screenshot: {
    names: ["spectacle", "org.kde.spectacle", "applets-screenshooter", "accessories-screenshot", "org.gnome.Screenshot"],
    tile: ["#a9a9af", "#69696e"],
    art:
      `<path d="M70 104V82Q70 70 82 70H104M152 70H174Q186 70 186 82V104M186 152V174Q186 186 174 186H152M104 186H82Q70 186 70 174V152" fill="none" stroke="${white}" stroke-width="12" ${round}/>` +
      `<circle cx="128" cy="128" r="23" fill="none" stroke="${white}" stroke-width="12"/>`,
  },
  // A chip on its legs.
  "system-info": {
    names: ["hwinfo", "kinfocenter", "org.kde.kinfocenter", "computer-info"],
    tile: ["#5fd6c9", "#17988c"],
    art:
      `<g fill="${white}">${legs}<rect x="84" y="84" width="88" height="88" rx="14"/></g>` +
      `<rect x="106" y="106" width="44" height="44" rx="7" fill="#22a99c"/>`,
  },
};

/** Icons drawn before this file (assets/icons/), and the other names they
 *  answer to in the theme: KDE's own settings and file manager wear ours. */
export const adopted: Record<string, string[]> = {
  "org.ambrosia.files": ["system-file-manager", "org.kde.dolphin", "file-manager"],
  "org.ambrosia.settings": ["systemsettings", "org.kde.systemsettings", "preferences-system", "preferences-desktop"],
};
