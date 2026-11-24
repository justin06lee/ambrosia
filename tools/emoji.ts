// Writes shell/emoji.js, the emoji picker's list (shell/EmojiPicker.qml):
// every emoji a keyboard should offer, in a Mac's eight groups, each with
// its name and the words it can be found by.
//
//   bun tools/emoji.ts [folder] [--upto 17.0]
//
// From Unicode's emoji-test.txt (which emoji, their order and names) and
// CLDR's English annotations (the words). With a folder it reads
// emoji-test.txt, en.xml and en-derived.xml there; without, it fetches them.
// Run by hand when Unicode adds emoji; the result is kept in the repo, so
// nothing is fetched at build time. --upto leaves out emoji newer than the
// font draws.
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const sources = {
  "emoji-test.txt": "https://unicode.org/Public/emoji/latest/emoji-test.txt",
  "en.xml": "https://raw.githubusercontent.com/unicode-org/cldr/main/common/annotations/en.xml",
  "en-derived.xml": "https://raw.githubusercontent.com/unicode-org/cldr/main/common/annotationsDerived/en.xml",
};

const args = process.argv.slice(2);
const uptoAt = args.indexOf("--upto");
const upto = uptoAt >= 0 ? Number(args.splice(uptoAt, 2)[1]) : Infinity;
const folder = args[0];

async function read(name: keyof typeof sources): Promise<string> {
  if (folder) return readFileSync(join(folder, name), "utf8");
  const answer = await fetch(sources[name]);
  if (!answer.ok) throw new Error(`${sources[name]}: ${answer.status}`);
  return answer.text();
}

// A Mac's groups, in its order, and the Unicode groups each takes.
const groups: [string, string[]][] = [
  ["Smileys & People", ["Smileys & Emotion", "People & Body"]],
  ["Animals & Nature", ["Animals & Nature"]],
  ["Food & Drink", ["Food & Drink"]],
  ["Activity", ["Activities"]],
  ["Travel & Places", ["Travel & Places"]],
  ["Objects", ["Objects"]],
  ["Symbols", ["Symbols"]],
  ["Flags", ["Flags"]],
];

// CLDR names an emoji without its variation selector.
const bare = (emoji: string) => emoji.replaceAll("️", "");
const unescape = (text: string) =>
  text.replaceAll("&amp;", "&").replaceAll("&lt;", "<").replaceAll("&gt;", ">").replaceAll("&quot;", '"').replaceAll("&apos;", "'");

const words = new Map<string, string[]>();
for (const name of ["en.xml", "en-derived.xml"] as const) {
  const xml = await read(name);
  for (const [, cp, type, text] of xml.matchAll(/<annotation cp="([^"]+)"( type="tts")?>([^<]*)<\/annotation>/g)) {
    if (type) continue;
    words.set(bare(unescape(cp!)), unescape(text!).split("|").map(word => word.trim().toLowerCase()).filter(Boolean));
  }
}

const test = await read("emoji-test.txt");
const version = /^# Version: (\S+)/m.exec(test)?.[1] ?? "?";
const lists = new Map<string, string[]>();
let group = "";
let count = 0;
for (const line of test.split("\n")) {
  const heading = /^# group: (.+)$/.exec(line);
  if (heading) {
    group = heading[1]!.trim();
    continue;
  }
  // 1F600 ; fully-qualified # 😀 E1.0 grinning face
  const entry = /^([0-9A-F ]+?)\s*;\s*fully-qualified\s*#\s*(\S+)\s+E(\d+\.\d+)\s+(.+)$/.exec(line);
  if (!entry) continue;
  const points = entry[1]!.split(" ").map(hex => parseInt(hex, 16));
  // One of each: the skin tones are a choice made on an emoji, not emoji.
  if (points.some(point => point >= 0x1f3fb && point <= 0x1f3ff)) continue;
  if (Number(entry[3]) > upto) continue;
  const emoji = entry[2]!;
  const name = entry[4]!.trim();
  const inName = new Set(name.toLowerCase().split(/[^\p{L}\p{N}]+/u));
  const extra = (words.get(bare(emoji)) ?? []).filter(word => !inName.has(word) && !name.toLowerCase().includes(word));
  const list = lists.get(group) ?? [];
  list.push([emoji, name, [...new Set(extra)].join(" ")].join("\t"));
  lists.set(group, list);
  count++;
}

const out = groups.map(([name, from]) => [name, from.flatMap(g => lists.get(g) ?? []).join("\n")]);
const file = `.pragma library
// The emoji picker's list (EmojiPicker.qml): a Mac's eight groups, and in
// each a line an emoji, "emoji<tab>name<tab>words to find it by".
// Written by tools/emoji.ts from Unicode's emoji-test.txt (Emoji ${version}) and
// CLDR's English annotations, © Unicode, Inc., under the Unicode License v3
// (https://www.unicode.org/license.txt). ${count} emoji. Don't edit by hand.

var groups = [
${out.map(([name, lines]) => `    [${JSON.stringify(name)}, ${JSON.stringify(lines)}],`).join("\n")}
];
`;
writeFileSync(join(import.meta.dir, "..", "shell", "emoji.js"), file);
console.log(`shell/emoji.js: ${count} emoji in ${out.length} groups (Emoji ${version}${upto < Infinity ? `, up to ${upto}` : ""}), ${file.length} characters`);
