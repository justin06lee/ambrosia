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
  /** The names apps ask for it by; the first is the file, the rest link to it.
   *  The first is the `Icon=` of the app we ship (read from its desktop file
   *  upstream, 2026-11-18); the others are that kind of app's usual names. */
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
    names: ["org.ambrosia.textedit", "kate", "org.kde.kate", "kwrite", "org.kde.kwrite", "accessories-text-editor", "text-editor"],
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
    names: ["org.ambrosia.preview", "gwenview", "org.kde.gwenview", "image-viewer", "multimedia-photo-viewer", "eog", "org.gnome.eog"],
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
    names: ["org.ambrosia.archive", "ark", "org.kde.ark", "utilities-file-archiver", "file-roller", "org.gnome.FileRoller"],
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
  // A dark screen and the trace running across it.
  "activity-monitor": {
    names: [
      "org.ambrosia.activitymonitor", "utilities-system-monitor", "org.kde.plasma-systemmonitor", "plasma-systemmonitor",
      "ksysguard", "org.kde.ksysguard", "org.gnome.SystemMonitor", "gnome-system-monitor", "system-monitor",
    ],
    tile: ["#5a5a60", "#2a2a2d"],
    art:
      `<rect x="46" y="62" width="164" height="132" rx="20" fill="#0f0f11"/>` +
      `<path d="M128 70V186M87 70V186M169 70V186M54 128H202M54 98H202M54 158H202" fill="none" stroke="#2a2c2e" stroke-width="3"/>` +
      `<path d="M58 140H86L99 108L116 172L135 84L152 152L163 128H198" fill="none" stroke="#54e37a" stroke-width="10" ${round}/>`,
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
 *  answer to in the theme: KDE's own settings and file manager wear ours.
 *  Not "preferences-system" or "preferences-desktop": with either, every
 *  settings module's own icon (preferences-desktop-display, …) would be this
 *  one, since a name the theme lacks is cut down to one it has. */
export const adopted: Record<string, string[]> = {
  "org.ambrosia.files": ["system-file-manager", "org.kde.dolphin", "file-manager"],
  "org.ambrosia.settings": ["systemsettings", "org.kde.systemsettings"],
};

// ---------------------------------------------------------------------------
// Folders and documents: what a file dialog, another file manager and the
// Dock's Downloads stack show. The folder, the page, the song's tile and the
// Trash are the art Files and the Dock already draw (files/art/, shell/); what
// is here is what goes on them, and the names apps ask for them by.

const circle = (cx: number, cy: number, r: number) => `M${cx - r} ${cy}a${r} ${r} 0 1 0 ${2 * r} 0a${r} ${r} 0 1 0 ${-2 * r} 0z`;
const box = (x: number, y: number, w: number, h: number, r: number) =>
  `M${x + r} ${y}h${w - 2 * r}a${r} ${r} 0 0 1 ${r} ${r}v${h - 2 * r}a${r} ${r} 0 0 1 ${-r} ${r}` +
  `h${2 * r - w}a${r} ${r} 0 0 1 ${-r} ${-r}v${2 * r - h}a${r} ${r} 0 0 1 ${r} ${-r}z`;

/** A folder's outline on the 24 grid. */
const folderLine = "M3 7.5a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2V17a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z";

/** Line glyphs on a 24 grid, drawn 1.5 wide with round ends: the ones Files'
 *  sidebar draws (files/qml/glyphs.js) and a few more in the same hand. A
 *  special folder wears its glyph pressed into its front; at a sidebar's size
 *  the glyph alone is its icon, as in a Mac's sidebar. */
export const glyphs = {
  folder: folderLine,
  home: "M3.5 11.2L12 4l8.5 7.2M6 9.2V19a1 1 0 0 0 1 1h3.4v-5.2h3.2V20H17a1 1 0 0 0 1-1V9.2",
  desktop: box(3, 4.5, 18, 15, 2.5) + "M3 15h18",
  documents: "M6.5 3.5h7l4.5 4.5v11a1.5 1.5 0 0 1-1.5 1.5h-10A1.5 1.5 0 0 1 5 19V5a1.5 1.5 0 0 1 1.5-1.5zM13.5 3.5V8H18",
  downloads: circle(12, 12, 8.75) + "M12 7.2v9.2M8.4 12.9l3.6 3.6 3.6-3.6",
  pictures: box(3, 5, 18, 14, 2.5) + circle(8.3, 9.8, 1.5) + "M3.6 16.4l4.6-4.2 3.5 3.1 2.9-2.6 5.8 5.2",
  music: "M9 17.6V6.4l10-2.1v11.2" + circle(6.75, 17.6, 2.25) + circle(16.75, 15.5, 2.25),
  videos: box(3, 5, 18, 14, 2.5) + "M7.5 5v14M16.5 5v14M3 9.7h4.5M3 14.3h4.5M16.5 9.7H21M16.5 14.3H21",
  public: circle(12, 8.3, 3.3) + "M5.2 19.6c.7-3.5 3.3-5.5 6.8-5.5s6.1 2 6.8 5.5",
  network: circle(12, 12, 8.5) + "M3.5 12h17M12 3.5c2.4 2.5 3.5 5.5 3.5 8.5s-1.1 6-3.5 8.5c-2.4-2.5-3.5-5.5-3.5-8.5s1.1-6 3.5-8.5z",
  trash: "M4.5 6.5h15M9.5 6.5V4.8a1 1 0 0 1 1-1h3a1 1 0 0 1 1 1v1.7M6.3 6.5l.9 12.6a1.6 1.6 0 0 0 1.6 1.4h6.4a1.6 1.6 0 0 0 1.6-1.4l.9-12.6M10 10v7M14 10v7",
  recent: circle(12, 12, 8.75) + "M12 7v5.2l3.4 2.1",
  folderNew: folderLine + "M12 10.4v5.6M9.2 13.2h5.6",
  folderSync: folderLine + "M9.3 12.5a2.8 2.8 0 0 1 5-1.1M14.7 13.9a2.8 2.8 0 0 1-5 1.1M14.6 9.6v1.9h-1.9M9.4 16.8v-1.9h1.9",
  folderStash: folderLine + "M12 10.2v5.4M9.8 13.4l2.2 2.2 2.2-2.2",
} as const;
export type Glyph = keyof typeof glyphs;

/** The same folder as one filled shape, for the name ending -symbolic: GTK
 *  fills every path of a symbolic icon, so a stroked line would come out a
 *  blob there. */
export const folderSymbol =
  "M2.25 7.5a2.75 2.75 0 0 1 2.75-2.75h4a.75.75 0 0 1 .53.22l1.78 1.78H19a2.75 2.75 0 0 1 2.75 2.75V17a2.75 2.75 0 0 1-2.75 2.75H5A2.75 2.75 0 0 1 2.25 17z" +
  "M3.75 7.5V17A1.25 1.25 0 0 0 5 18.25h14A1.25 1.25 0 0 0 20.25 17V9.5A1.25 1.25 0 0 0 19 8.25h-8a.75.75 0 0 1-.53-.22L8.69 6.25H5A1.25 1.25 0 0 0 3.75 7.5z";

/** Folders. The first name is the file; `glyph` is pressed into the folder's
 *  front, and is the whole icon under 32 px. Names as KIO's places and
 *  Breeze's folders have them (read 2026-11-18); any other folder-… name ends
 *  at the plain folder (see `kdeFinds` in tools/gen/lookup.ts). */
export const places: { names: string[]; glyph?: Glyph }[] = [
  { names: ["folder", "inode-directory"] },
  { names: ["user-home", "folder-home"], glyph: "home" },
  { names: ["user-desktop", "folder-desktop"], glyph: "desktop" },
  { names: ["folder-documents", "folder-text", "folder-txt"], glyph: "documents" },
  { names: ["folder-downloads", "folder-download"], glyph: "downloads" },
  { names: ["folder-pictures", "folder-picture", "folder-images", "folder-image"], glyph: "pictures" },
  { names: ["folder-music", "folder-sound"], glyph: "music" },
  { names: ["folder-videos", "folder-video"], glyph: "videos" },
  { names: ["folder-public", "folder-publicshare"], glyph: "public" },
  { names: ["folder-network", "folder-remote", "network-workgroup"], glyph: "network" },
];

/** A folder given a color (Dolphin's shortcut menu offers a row of them), as
 *  "folder-<name>": the folder with its blues moved to that hue. Files' tag
 *  colors where it has the color (files/src/main.cpp), a Mac's for the rest. */
export const folderTints: Record<string, string> = {
  red: "#e6524c",
  orange: "#ec9647",
  yellow: "#f0c43c",
  green: "#66c966",
  cyan: "#4cc3d6",
  blue: "#4089f2",
  violet: "#c043dc",
  magenta: "#e8589c",
  brown: "#a98a66",
  grey: "#98989d",
  black: "#55555a",
};

/** The Trash as the Dock draws it (shell/trash-*.svg), under the names a
 *  file manager asks for; under 32 px, the line bin. */
export const trash = { "user-trash": "trash-empty", "user-trash-full": "trash-full" } as const;

/** Breeze's one-color icons whose names begin "folder-": a theme that has
 *  "folder" answers for every folder-… name it lacks before Breeze is asked,
 *  so these would all turn into the plain folder (a New Folder button with no
 *  plus). They're drawn here instead, as lines at every size. */
export const folderActions: { names: string[]; glyph: Glyph }[] = [
  { names: ["folder-new", "folder-add"], glyph: "folderNew" },
  { names: ["folder-open-recent"], glyph: "recent" },
  { names: ["folder-sync"], glyph: "folderSync" },
  { names: ["folder-stash"], glyph: "folderStash" },
  { names: ["folder-edit-sign-encrypt", "folder-edit-sign-decrypted"], glyph: "folder" },
];

const line = (d: string, color: string, width: number) => `<path d="${d}" fill="none" stroke="${color}" stroke-width="${width}" ${round}/>`;
const P = "#c8c8cc"; // what's written on a page
const pdfRed = "#ff453a";
const sheetGreen = "#30b158";
const slideOrange = "#ff9f0a";

export type FileKind = {
  /** What it's drawn on: Files' page (files/art/document.svg), or the song's
   *  tile (audio.svg) with or without its notes. */
  on: "page" | "tile" | "song";
  /** The mark, on the page's or the tile's 128 grid, and on the 16 grid of
   *  what is used under 32 px: the small page (document-small.svg), or for a
   *  tile `smallTile`, with an edge that holds on white. */
  art: string;
  small?: string;
  /** Every name is spelled out. Never a bare "text-x-generic", "image-x-generic"
   *  and so on: KDE ends every text-… name a theme lacks at that one before it
   *  asks the next theme, so Breeze's text-field or audio-volume-high would
   *  become a page (a test holds this). */
  names: string[];
};

/** A tile under 32 px, on a 16 grid. */
export const smallTile = `<rect x="1.8" y="1.8" width="12.4" height="12.4" rx="2.4" fill="#f2f2f2" stroke="#b4b4b4" stroke-width="0.6"/>`;
const smallMark = "#a4a4aa";

/** Kinds of file, as a page with a mark on it. A picture is its own icon
 *  wherever there are previews; these show where there are none. */
export const fileKinds: Record<string, FileKind> = {
  // Nothing known about it: the bare page.
  blank: {
    on: "page",
    art: "",
    small: "",
    names: ["unknown", "application-octet-stream", "application-x-zerosize"],
  },
  // Writing.
  text: {
    on: "page",
    art: [52, 63, 74, 85, 96].map((y, i) => line(`M36 ${y}h${i === 4 ? 34 : 56}`, P, 4)).join(""),
    small: line("M5 6.6h6M5 8.4h6M5 10.2h6M5 12h4", "#c6c6c6", 0.6),
    names: [
      "text-plain", "text-x-plain", "text-markdown", "text-x-markdown", "text-x-readme", "text-x-log", "text-x-authors",
      "text-x-copying", "text-x-changelog", "text-x-credits", "text-x-install", "text-x-nfo", "text-rtf", "text-richtext",
      "text-enriched", "application-rtf", "x-office-document", "application-msword", "application-vnd.ms-word",
      "application-vnd.openxmlformats-officedocument.wordprocessingml.document", "application-vnd.oasis.opendocument.text",
      "application-x-abiword",
    ],
  },
  // Something written for a machine: </>.
  code: {
    on: "page",
    art: line("M53 60L38 75l15 15M75 60l15 15-15 15M69 54L59 96", "#a4a4aa", 5),
    small: line("M6.9 7.7L5.2 9.4l1.7 1.7M9.1 7.7l1.7 1.7-1.7 1.7", "#9a9aa0", 0.8),
    names: [
      "text-x-script", "text-x-python", "text-x-python2", "text-x-python3", "text-x-csrc", "text-x-chdr", "text-x-c++src",
      "text-x-c++hdr", "text-x-objcsrc", "text-x-java", "text-x-java-source", "text-javascript", "text-x-javascript",
      "application-javascript", "application-x-javascript", "application-json", "application-xml", "text-xml", "text-html",
      "application-xhtml+xml", "text-css", "text-x-scss", "text-x-sass", "text-rust", "text-x-rust", "text-x-go", "text-x-lua",
      "text-x-qml", "text-x-cmake", "text-x-makefile", "text-x-shellscript", "application-x-shellscript", "application-x-perl",
      "application-x-php", "application-x-ruby", "text-x-kotlin", "text-csharp", "text-x-csharp", "text-x-sql", "application-sql",
      "application-toml", "application-x-yaml", "text-x-patch", "text-x-tex", "text-x-haskell", "text-x-scala",
      // As file(1) names them, which is what the Dock's stack asks by.
      "text-x-script.python", "text-x-c", "text-x-c++", "text-x-perl", "text-x-ruby", "text-x-php", "text-x-diff",
    ],
  },
  // A red label with its three letters, drawn as strokes so no font is needed.
  pdf: {
    on: "page",
    art:
      [50, 61, 72].map((y) => line(`M36 ${y}h56`, P, 4)).join("") +
      `<rect x="33" y="82" width="62" height="25" rx="6" fill="${pdfRed}"/>` +
      line("M45 101V88h4.4a3.9 3.9 0 0 1 0 7.8H45M59.5 88v13h2.6a6.5 6.5 0 0 0 0-13zM76 101V88h8M76 94.6h6", white, 3),
    small: line("M5 6.2h6M5 7.8h6", "#c6c6c6", 0.6) + `<rect x="4.6" y="9.1" width="6.8" height="3.7" rx="0.9" fill="${pdfRed}"/>`,
    names: ["application-pdf", "application-x-pdf", "gnome-mime-application-pdf"],
  },
  // A picture: sky, sun and hills, as on the picture viewer's icon.
  image: {
    on: "page",
    art:
      `<rect x="34" y="52" width="60" height="46" rx="5" fill="#a8dcff"/>` +
      `<circle cx="80" cy="65" r="5.5" fill="#ffd042"/>` +
      `<path d="M34 93V86l13-15q3-3.4 6 0l12 14 6-6.5q3-3 6 0l11 14.5a5 5 0 0 1-5 5H39a5 5 0 0 1-5-5z" fill="#3f9a63"/>`,
    small:
      `<rect x="4.8" y="6.9" width="6.4" height="5.2" rx="0.7" fill="#a8dcff"/>` +
      `<path d="M4.8 11.4v-0.8l2-2.2 1.7 1.9 1-1 1.7 1.9v0.2a0.7 0.7 0 0 1-0.7 0.7H5.5a0.7 0.7 0 0 1-0.7-0.7z" fill="#3f9a63"/>`,
    names: [
      "image-png", "image-jpeg", "image-gif", "image-bmp", "image-tiff", "image-webp", "image-svg+xml",
      "image-svg+xml-compressed", "image-x-icon", "image-vnd.microsoft.icon", "image-heif", "image-heic", "image-avif",
      "image-jxl", "image-jpeg2000", "image-x-xcf", "image-x-psd", "image-vnd.adobe.photoshop", "image-x-tga",
      "image-x-portable-pixmap", "image-x-portable-bitmap", "image-x-portable-graymap", "image-x-adobe-dng",
      "image-x-canon-cr2", "image-x-nikon-nef", "image-x-sony-arw",
    ],
  },
  // A song without a cover: Files' tile, as it is.
  audio: {
    on: "song",
    art: "",
    small:
      line("M6.5 10.5V5.4l4.1-0.9v5.2", smallMark, 0.8) +
      `<circle cx="5.5" cy="10.5" r="1.1" fill="${smallMark}"/><circle cx="9.6" cy="9.7" r="1.1" fill="${smallMark}"/>`,
    names: [
      "audio-mpeg", "audio-mp3", "audio-mp2", "audio-mp4", "audio-x-m4a", "audio-aac", "audio-flac", "audio-x-flac",
      "audio-ogg", "audio-x-vorbis+ogg", "audio-x-opus+ogg", "audio-x-flac+ogg", "audio-x-wav", "audio-vnd.wave",
      "audio-x-aiff", "audio-midi", "audio-x-ms-wma", "audio-webm", "audio-ac3", "audio-x-mpeg",
    ],
  },
  // A film without a frame to show: the same tile with a play mark.
  video: {
    on: "tile",
    art: `<path d="M53 46L88 64 53 82z" fill="#cdcdcd" stroke="#cdcdcd" stroke-width="8" stroke-linejoin="round"/>`,
    small: `<path d="M6.6 5.7L10.6 8 6.6 10.3z" fill="${smallMark}" stroke="${smallMark}" stroke-width="0.8" stroke-linejoin="round"/>`,
    names: [
      "video-mp4", "video-x-matroska", "video-webm", "video-quicktime", "video-x-msvideo", "video-mpeg", "video-x-flv",
      "video-x-ms-wmv", "video-x-wmv", "video-ogg", "video-x-theora+ogg", "video-x-ogm+ogg", "video-mp2t", "video-3gpp",
      "video-x-m4v",
    ],
  },
  // Things packed into one: a zip down the page.
  archive: {
    on: "page",
    art:
      Array.from({ length: 6 }, (_, i) => {
        const y = 12 + i * 10;
        return `<rect x="56" y="${y}" width="9" height="5" rx="1.5" fill="${P}"/><rect x="64" y="${y + 5}" width="9" height="5" rx="1.5" fill="${P}"/>`;
      }).join("") +
      `<rect x="54.5" y="74" width="20" height="24" rx="5" fill="none" stroke="#b4b4ba" stroke-width="4"/>` +
      `<rect x="60.5" y="84" width="8" height="8" rx="2" fill="#b4b4ba"/>`,
    small: `<path d="M8 1.9v6.2" fill="none" stroke="#b4b4ba" stroke-width="1.5" stroke-dasharray="0.9 0.9"/><rect x="6.9" y="8.9" width="2.2" height="3" rx="0.6" fill="none" stroke="#a9a9af" stroke-width="0.7"/>`,
    names: [
      "package-x-generic", "application-zip", "application-x-zip", "application-x-tar", "application-x-compressed-tar",
      "application-gzip", "application-x-gzip", "application-x-bzip", "application-x-bzip2",
      "application-x-bzip-compressed-tar", "application-x-bzip2-compressed-tar", "application-x-xz",
      "application-x-xz-compressed-tar", "application-zstd", "application-x-zstd-compressed-tar",
      "application-x-lzma-compressed-tar", "application-x-7z-compressed", "application-x-rar", "application-vnd.rar",
      "application-x-archive", "application-x-cpio", "application-x-tarz", "application-x-compress", "application-x-lha",
      "application-x-ar",
    ],
  },
  // Rows and columns.
  spreadsheet: {
    on: "page",
    art:
      `<path d="M38 52h52a4 4 0 0 1 4 4v9H34v-9a4 4 0 0 1 4-4z" fill="${sheetGreen}"/>` +
      line(box(34, 52, 60, 48, 4) + "M34 65h60M34 76h60M34 88h60M54 65v35M74 65v35", sheetGreen, 3),
    small:
      `<path d="M5.3 6.7h5.4a0.5 0.5 0 0 1 0.5 0.5v1.1H4.8V7.2a0.5 0.5 0 0 1 0.5-0.5z" fill="${sheetGreen}"/>` +
      line("M4.8 8.3h6.4M4.8 10.3h6.4M8 8.3v4.1" + box(4.8, 6.7, 6.4, 5.7, 0.5), sheetGreen, 0.6),
    names: [
      "x-office-spreadsheet", "application-vnd.ms-excel", "application-vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      "application-vnd.oasis.opendocument.spreadsheet", "text-csv", "text-tab-separated-values", "application-x-gnumeric",
    ],
  },
  // A slide on its stand.
  presentation: {
    on: "page",
    art:
      `<rect x="34" y="52" width="60" height="38" rx="5" fill="${slideOrange}"/>` +
      line("M46 80V70M56 80V62M66 80V72", white, 5) +
      line("M64 90v12M52 104h24", slideOrange, 4),
    small: `<rect x="4.8" y="6.9" width="6.4" height="4.2" rx="0.7" fill="${slideOrange}"/>` + line("M8 11.1v1.4M6.6 12.6h2.8", slideOrange, 0.6),
    names: [
      "x-office-presentation", "application-vnd.ms-powerpoint",
      "application-vnd.openxmlformats-officedocument.presentationml.presentation",
      "application-vnd.oasis.opendocument.presentation",
    ],
  },
};
