// System-wide font defaults: which families answer to sans-serif / monospace /
// system-ui, and how glyphs are rasterized (see DESIGN.md › Typography).

import * as t from "../../../design/tokens";
import { HEADER } from "./shared";

const prefer = (alias: string, families: readonly string[]) =>
  `  <alias binding="same">
    <family>${alias}</family>
    <prefer>
${families.map((f) => `      <family>${f}</family>`).join("\n")}
    </prefer>
  </alias>`;

const assign = (name: string, value: string) =>
  `    <edit name="${name}" mode="assign">${value}</edit>`;

export const fontconfig = () => `<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<!-- ${HEADER} -->
<fontconfig>
  <match target="font">
${assign("antialias", "<bool>true</bool>")}
${assign("hinting", "<bool>true</bool>")}
${assign("hintstyle", "<const>hintslight</const>")}
${assign("rgba", "<const>none</const>")}
${assign("lcdfilter", "<const>lcdnone</const>")}
${assign("embeddedbitmap", "<bool>false</bool>")}
  </match>

${prefer("sans-serif", t.font.ui)}
${prefer("system-ui", t.font.ui)}
${prefer("monospace", t.font.mono)}
</fontconfig>
`;

/** Slight hinting runs FreeType's autofitter, whose stem darkening is opt-in. */
export const fontEnvironment = () =>
  `# ${HEADER}\nFREETYPE_PROPERTIES="autofitter:no-stem-darkening=0 cff:no-stem-darkening=0"\n`;
