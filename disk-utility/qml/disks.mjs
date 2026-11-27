// What Disk Utility lists and says: the disks and volumes of the sidebar,
// a page's words, bar and table, what each button may do, the Info
// window's rows. The C++ Disks only reads UDisks2 (blocks and drives as
// plain maps) and does what it is told; this decides. Shared with bun
// (disk-utility/disks.test.ts), so it keeps to what QML's JavaScript runs:
// no object spread, no `??=`.

// A size as a Mac writes one: decimal units, no decimals for KB, one for
// MB, two from GB up, with the zeros at the end left off (245.11 GB,
// 524.3 MB, 1 TB).
export function sizeText(bytes) {
    if (!(bytes > 0))
        return "Zero KB";
    if (bytes < 1000)
        return bytes + (bytes === 1 ? " byte" : " bytes");
    const units = [["KB", 1e3, 0], ["MB", 1e6, 1], ["GB", 1e9, 2], ["TB", 1e12, 2], ["PB", 1e15, 2]];
    for (let at = 0; at < units.length; ++at) {
        const fixed = (bytes / units[at][1]).toFixed(units[at][2]);
        if (Number(fixed) < 1000 || at === units.length - 1)
            return String(Number(fixed)) + " " + units[at][0];
    }
    return "";
}

// A count of bytes with its thousands marked (999,995,129,856).
export function bytesText(bytes) {
    const digits = String(Math.max(0, Math.round(bytes)));
    let out = "";
    for (let at = 0; at < digits.length; ++at) {
        if (at > 0 && (digits.length - at) % 3 === 0)
            out += ",";
        out += digits[at];
    }
    return out;
}

// A file system by the name a Mac's Disk Utility gives it, or its own
// where a Mac has none.
export function fsName(type, version) {
    switch (type) {
    case "vfat": return version === "FAT32" || version === "FAT16" || version === "FAT12" ? "MS-DOS (" + version + ")" : "MS-DOS (FAT)";
    case "exfat": return "ExFAT";
    case "ntfs": return "Windows NT File System (NTFS)";
    case "hfsplus": return "Mac OS Extended";
    case "hfs": return "Mac OS Standard";
    case "apfs": return "APFS";
    case "btrfs": return "Btrfs";
    case "xfs": return "XFS";
    case "f2fs": return "F2FS";
    case "iso9660": return "ISO 9660";
    case "udf": return "Universal Disk Format (UDF)";
    case "squashfs": return "SquashFS";
    case "swap": return "Linux Swap";
    case "crypto_LUKS": return "LUKS";
    case "LVM2_member": return "LVM Physical Volume";
    case "linux_raid_member": return "RAID Member";
    case "": case undefined: case null: return "Free Space";
    default: return type;
    }
}

// The formats Erase offers, in a Mac's order of use here: `types` are
// those UDisks2 can make on this computer (their tools are installed).
const eraseNames = [["ext4", "ext4"], ["exfat", "ExFAT"], ["vfat", "MS-DOS (FAT)"], ["btrfs", "Btrfs"], ["xfs", "XFS"], ["ntfs", "Windows NT File System (NTFS)"]];
export function eraseFormats(types) {
    return eraseNames.filter(entry => types.includes(entry[0])).map(entry => ({ type: entry[0], name: entry[1] }));
}
export const schemes = [{ key: "gpt", name: "GUID Partition Map" }, { key: "dos", name: "Master Boot Record" }];
export function schemeName(table) {
    return table === "gpt" ? "GUID Partition Map" : table === "dos" ? "Master Boot Record" : "Not Supported";
}

// The name a file system of this kind can carry, from what was typed:
// each has its own length, and FAT's is in capitals.
export function labelFor(type, name) {
    const typed = String(name).trim();
    const most = { vfat: 11, exfat: 15, ext2: 16, ext3: 16, ext4: 16, xfs: 12, ntfs: 32, btrfs: 255, f2fs: 127 }[type] ?? 16;
    let label = "";
    // By bytes, as the file systems count: a letter outside ASCII takes
    // more than one.
    let used = 0;
    for (const letter of typed) {
        const bytes = letter.codePointAt(0) < 0x80 ? 1 : letter.codePointAt(0) < 0x800 ? 2 : letter.codePointAt(0) < 0x10000 ? 3 : 4;
        if (type === "vfat" && (bytes > 1 || "\"*/:<>?\\|+,.;=[]".includes(letter)))
            continue;
        if (used + bytes > most)
            break;
        label += letter;
        used += bytes;
    }
    return type === "vfat" ? label.toUpperCase() : label;
}

// A place a volume is mounted for the system's own use: nothing here
// unmounts or erases it. What a person plugs in is mounted under
// /run/media (or the older /media) and what they mount by hand under /mnt.
export function systemMount(path) {
    return !(path.startsWith("/run/media/") || path.startsWith("/media/") || path.startsWith("/mnt/"));
}

// Names in order, their numbers by size (loop2 before loop10).
function natural(a, b) {
    const split = (text) => String(text).match(/\d+|\D+/g) ?? [];
    const one = split(a), other = split(b);
    for (let at = 0; at < Math.min(one.length, other.length); ++at) {
        if (one[at] === other[at])
            continue;
        const numbers = /^\d/.test(one[at]) && /^\d/.test(other[at]);
        if (numbers)
            return Number(one[at]) - Number(other[at]);
        return one[at] < other[at] ? -1 : 1;
    }
    return one.length - other.length;
}

function shortName(device) {
    return String(device).replace(/^\/dev\//, "");
}

// How a drive is connected, in a Mac's words where it has them.
export function connection(drive, device) {
    const name = shortName(device);
    if (drive) {
        if (drive.bus === "usb") return "USB";
        if (drive.bus === "ieee1394") return "FireWire";
        if (drive.bus === "sdio") return "Secure Digital";
    }
    if (name.startsWith("nvme")) return "PCI-Express";
    if (name.startsWith("mmcblk")) return "Secure Digital";
    if (name.startsWith("vd")) return "VirtIO";
    if (name.startsWith("loop")) return "Disk Image";
    if (name.startsWith("sr")) return "SATA";
    if (name.startsWith("sd")) return "SATA";
    return "Internal";
}

function external(drive) {
    return !!drive && (drive.removable || drive.mediaRemovable || drive.bus === "usb" || drive.bus === "ieee1394" || drive.bus === "sdio");
}

// Everything, put in order: the disks (a drive's whole block, a disk
// image's loop device, or a volume that stands on no disk we know) with
// their volumes. A volume is a block that holds a file system or an
// encrypted one; `fs` is the block the file system is on (the opened inside
// of an encrypted one). Those a person never sees (the EFI partition, swap,
// an extended partition's shell) are `hidden`: a disk's bar counts them, the
// sidebar doesn't list them.
export function model(blocks, drives) {
    const byPath = new Map();
    for (const block of blocks)
        byPath.set(block.path, block);
    const driveByPath = new Map();
    for (const drive of drives)
        driveByPath.set(drive.path, drive);
    // The opened inside of each encrypted block.
    const inside = new Map();
    for (const block of blocks) {
        if (block.backing)
            inside.set(block.backing, block);
    }

    function volume(block, disk) {
        const inner = inside.get(block.path) ?? null;
        const fs = inner ?? block;
        const encrypted = block.usage === "crypto" || !!block.encrypted;
        const mounts = fs.mounts ?? [];
        const swap = fs.usage === "other" && fs.type === "swap";
        const holds = fs.usage === "filesystem" || encrypted;
        const system = mounts.some(systemMount) || (swap && !!fs.swapActive);
        const label = fs.label || (encrypted && !inner ? block.label : "") || "";
        return {
            key: block.path, kind: "volume", disk: disk.key, block: block, inner: inner, fs: fs,
            name: label !== "" ? label : !holds ? fsName(block.type, block.version) : "Untitled",
            encrypted: encrypted, locked: encrypted && !inner,
            mounted: mounts.length > 0, mountPoint: mounts[0] ?? "", system: system,
            holds: holds,
            hidden: !holds || !!block.hintIgnore || !!block.container || !(block.size > 0),
            size: block.size, total: fs.total ?? 0, free: fs.free ?? 0, available: fs.available ?? 0,
        };
    }

    const disks = [];
    const placed = new Set();
    // Whole disks: a block of a drive that is no partition, and a disk
    // image's loop device.
    for (const block of blocks) {
        if (block.partition || block.backing || !(block.size > 0))
            continue;
        const drive = driveByPath.get(block.drive) ?? null;
        if (!drive && !block.loop)
            continue;
        if (drive && !drive.mediaAvailable)
            continue;
        const section = block.loop ? "image" : external(drive) ? "external" : "internal";
        const disk = {
            key: block.path, kind: "disk", section: section, block: block, drive: drive,
            name: block.loop ? "Disk Image Media" : (([drive.vendor, drive.model].filter(word => word).join(" ") || "Disk") + " Media"),
            size: block.size, parts: [], volumes: [],
        };
        placed.add(block.path);
        if (block.partitioned) {
            const parts = blocks.filter(part => part.partition && part.partTable === block.path).sort((a, b) => a.offset - b.offset);
            for (const part of parts) {
                placed.add(part.path);
                const made = volume(part, disk);
                if (made.inner)
                    placed.add(made.inner.path);
                disk.parts.push(made);
            }
        } else if (block.usage === "filesystem" || block.usage === "crypto") {
            // No partition map: the disk is one volume.
            const made = volume(block, disk);
            made.whole = true;
            // The disk's own key is the block's.
            made.key = block.path + "#whole";
            if (made.inner)
                placed.add(made.inner.path);
            disk.parts.push(made);
        }
        disk.volumes = disk.parts.filter(part => !part.hidden);
        disk.system = disk.parts.some(part => part.system);
        disks.push(disk);
    }
    // What stands on no disk we know (a logical volume, a RAID): a volume
    // of its own, listed with the internal ones.
    for (const block of blocks) {
        if (placed.has(block.path) || block.backing || block.loop || !(block.size > 0))
            continue;
        if (block.usage !== "filesystem" && block.usage !== "crypto")
            continue;
        const disk = { key: "logical:" + block.path, kind: "disk", section: "internal", block: null, drive: null, name: "Logical Volume", size: block.size, parts: [], volumes: [], logical: true };
        const made = volume(block, disk);
        if (made.inner)
            placed.add(made.inner.path);
        made.logical = true;
        disk.parts.push(made);
        disk.volumes = disk.parts.filter(part => !part.hidden);
        disk.system = made.system;
        if (disk.volumes.length > 0)
            disks.push(disk);
    }
    const order = { internal: 0, external: 1, image: 2 };
    disks.sort((a, b) => order[a.section] - order[b.section] || natural(a.block?.device ?? a.key, b.block?.device ?? b.key));
    return { disks: disks };
}

// The disk or volume of this key, or null.
export function find(all, key) {
    for (const disk of all.disks) {
        if (disk.key === key && !disk.logical)
            return disk;
        for (const part of disk.parts) {
            if (part.key === key)
                return part;
        }
    }
    return null;
}
export function diskOf(all, item) {
    if (!item)
        return null;
    return item.kind === "disk" ? item : (all.disks.find(disk => disk.key === item.disk) ?? null);
}

const sectionTitles = { internal: "Internal", external: "External", image: "Disk Images" };

// The sidebar: under Internal, External and Disk Images, the volumes
// (`everything` false, as a Mac's Show Only Volumes) or each disk with its
// volumes under it (Show All Devices); `collapsed` holds the keys of the
// disks shut. A disk with no volume to list stands there itself either way.
export function sidebar(all, everything, collapsed) {
    const sections = [];
    for (const key of ["internal", "external", "image"]) {
        const rows = [];
        for (const disk of all.disks.filter(disk => disk.section === key)) {
            const ejects = key !== "internal" && !disk.system;
            const bare = disk.logical || (!everything && disk.volumes.length > 0);
            if (!bare) {
                const shut = (collapsed ?? []).includes(disk.key);
                rows.push({ key: disk.key, level: 0, name: disk.name, glyph: key === "internal" ? "driveInternal" : "driveExternal", dim: false, eject: ejects, children: disk.volumes.length > 0, shut: shut });
                if (shut)
                    continue;
            }
            for (const part of disk.volumes) {
                rows.push({ key: part.key, level: bare ? 0 : 1, name: part.name, glyph: part.locked ? "volumeLocked" : "volume", dim: !part.mounted, eject: ejects && part.mounted, children: false, shut: false });
            }
        }
        if (rows.length > 0)
            sections.push({ key: key, title: sectionTitles[key], rows: rows });
    }
    return sections;
}

// The keys of a sidebar's rows, top to bottom.
export function keys(sections) {
    return sections.reduce((all, section) => all.concat(section.rows.map(row => row.key)), []);
}

// The first thing to choose when nothing is: the volume the system runs
// from, or the first one listed.
export function first(all, everything) {
    for (const disk of all.disks) {
        const root = disk.volumes.find(part => part.fs.mounts?.includes("/"));
        if (root)
            return root.key;
    }
    const rows = keys(sidebar(all, everything, []));
    return rows.length > 0 ? rows[0] : "";
}

function kindWords(disk, what) {
    if (!disk || disk.logical)
        return "Logical Volume";
    if (disk.section === "image")
        return what === "disk" ? "Disk Image" : "Disk Image Volume";
    return connection(disk.drive, disk.block.device) + (disk.section === "external" ? " External" : " Internal") + " Physical " + (what === "disk" ? "Disk" : "Volume");
}

// The colors of a disk's parts along its bar, in a Mac's order.
export const partColors = ["blue", "red", "orange", "yellow", "green", "purple", "pink", "teal"];

// A page's words: the title and the lines under it, the capacity in its
// box, the bar's parts ({ name, text, color, bytes }: a legend entry each),
// and the table's two columns of [label, value]. `system` is the
// computer's own name and version, said of the volume it runs from.
export function page(all, item, system) {
    if (!item)
        return null;
    const disk = diskOf(all, item);
    if (item.kind === "disk") {
        const block = item.block;
        const drive = item.drive;
        const bar = [];
        let at = 0;
        let end = 0;
        for (const part of item.parts) {
            if (part.whole) {
                bar.push({ name: part.name, text: sizeText(part.size), color: partColors[0], bytes: part.size });
                end = part.size;
                continue;
            }
            if (part.block.container)
                continue;
            bar.push({ name: part.hidden && !part.holds ? fsName(part.block.type, part.block.version) : part.name === "Untitled" && part.block.partName ? part.block.partName : part.name,
                       text: sizeText(part.size), color: partColors[at % partColors.length], bytes: part.size });
            end = Math.max(end, (part.block.offset ?? 0) + part.size);
            ++at;
        }
        // Room no partition takes, when it is worth a word (16 MB or more).
        const spare = item.size - bar.reduce((sum, part) => sum + part.bytes, 0);
        if (bar.length === 0)
            bar.push({ name: "Uninitialized", text: sizeText(item.size), color: "free", bytes: item.size });
        else if (spare >= 16e6)
            bar.push({ name: "Free Space", text: sizeText(spare), color: "free", bytes: spare });
        const scheme = block.partitioned ? schemeName(block.table) : item.parts.length > 0 ? fsName(item.parts[0].fs.type, item.parts[0].fs.version) : "Uninitialized";
        const image = item.section === "image";
        return {
            kind: "disk", icon: item.section,
            title: item.name,
            subtitle: kindWords(item, "disk") + " • " + scheme,
            third: "",
            capacity: sizeText(item.size), caption: "",
            bar: bar,
            left: [["Location:", image ? "Disk Image" : item.section === "external" ? "External" : "Internal"],
                   ["Connection:", connection(drive, block.device)],
                   ["Partition Map:", block.partitioned ? schemeName(block.table) : "Not Supported"],
                   image ? ["Image Path:", block.backingFile || "—"] : ["S.M.A.R.T. status:", smartText(drive)]],
            right: [["Capacity:", sizeText(item.size)],
                    ["Child count:", String(item.parts.filter(part => !part.whole).length)],
                    ["Type:", image ? "Disk Image" : drive && drive.optical ? "Optical" : drive && drive.rotation === 0 ? "Solid state" : drive && drive.rotation > 0 ? "Disk" : "Disk"],
                    ["Device:", shortName(block.device)]],
        };
    }
    const fs = item.fs;
    const type = item.locked ? item.block.type : fs.type;
    const words = item.locked ? "Encrypted" : fsName(fs.type, fs.version) + (item.encrypted ? " (Encrypted)" : "");
    const used = item.mounted ? Math.max(0, item.total - item.free) : -1;
    // A file system takes some of its partition for itself: what is left of
    // the partition beyond used and free counts as used, as a Mac's does.
    const capacity = item.size;
    const usedAll = item.mounted ? Math.max(0, capacity - item.free) : -1;
    const bar = item.mounted
        ? [{ name: "Used", text: sizeText(usedAll), color: "blue", bytes: usedAll }, { name: "Free", text: sizeText(item.free), color: "free", bytes: item.free }]
        : [{ name: "Used", text: "--", color: "blue", bytes: 0 }, { name: "Free", text: "--", color: "free", bytes: capacity }];
    const readOnly = item.mounted && (fs.readOnly || fs.mountedReadOnly);
    return {
        kind: "volume", icon: disk ? disk.section : "internal",
        title: item.name,
        subtitle: kindWords(disk, "volume") + " • " + words,
        third: fs.mounts?.includes("/") ? (system ?? "") : "",
        capacity: sizeText(capacity), caption: "",
        bar: bar,
        left: [[readOnly ? "Mount Point (Read-Only):" : "Mount Point:", item.mounted ? item.mountPoint : "Not Mounted"],
               ["Capacity:", sizeText(capacity)],
               ["Available:", item.mounted ? sizeText(item.available) : "Zero KB"],
               ["Used:", item.mounted ? sizeText(usedAll) : "--"]],
        right: [["Type:", kindWords(disk, "volume")],
                ["Owners:", item.locked ? "—" : owners(type) ? "Enabled" : "Disabled"],
                ["Connection:", disk && !disk.logical ? connection(disk.drive, disk.block.device) : "Internal"],
                ["Device:", shortName(item.block.device)]],
        used: used,
    };
}

function owners(type) {
    return !["vfat", "exfat", "ntfs", "iso9660", "udf", "hfsplus", "hfs", "", undefined, null].includes(type);
}
function smartText(drive) {
    return !drive || drive.smart === "unsupported" || !drive.smart ? "Not Supported" : drive.smart === "failing" ? "Failing" : "Verified";
}

// What the toolbar's buttons may do with what is chosen. Nothing touches
// what the system runs from; First Aid is for a volume whose file system
// has a checker here (`checkable` types).
export function can(all, item, checkable) {
    const none = { firstAid: false, erase: false, mount: false, mountLabel: "Unmount", eject: false, info: false };
    if (!item)
        return none;
    const disk = diskOf(all, item);
    if (item.kind === "disk") {
        const mounted = item.parts.some(part => part.mounted);
        return {
            firstAid: false,
            erase: !item.system && !item.block.readOnly,
            mount: !item.system && item.volumes.length > 0,
            mountLabel: mounted ? "Unmount" : "Mount",
            eject: item.section !== "internal" && !item.system,
            info: true,
        };
    }
    return {
        firstAid: !item.system && !item.locked && (checkable ?? []).includes(item.fs.type),
        erase: !item.system && !item.block.readOnly && !(disk && disk.block && disk.block.readOnly),
        mount: !item.system && item.holds,
        mountLabel: item.mounted ? "Unmount" : "Mount",
        eject: !!disk && disk.section !== "internal" && !disk.system,
        info: true,
    };
}

function yes(value) {
    return value ? "Yes" : "No";
}

// The Info window's rows, [name, value], as a Mac's lists them.
export function info(all, item) {
    if (!item)
        return [];
    const disk = diskOf(all, item);
    const drive = disk ? disk.drive : null;
    const where = disk && !disk.logical ? connection(drive, disk.block.device) : "Internal";
    if (item.kind === "disk") {
        const block = item.block;
        const rows = [
            ["Media name", item.name],
            ["Media type", item.section === "image" ? "Disk Image" : drive && drive.optical ? "Optical" : "Generic"],
            ["Device node", block.device],
            ["Connection", where],
            ["Location", item.section === "image" ? "Disk Image" : item.section === "external" ? "External" : "Internal"],
            ["Partition map", block.partitioned ? schemeName(block.table) : "None"],
            ["Disk capacity", bytesText(item.size)],
            ["Child count", String(item.parts.filter(part => !part.whole).length)],
            ["Writable", yes(!block.readOnly)],
            ["Ejectable", yes(item.section !== "internal")],
            ["Solid state", yes(!!drive && drive.rotation === 0)],
            ["S.M.A.R.T. status", smartText(drive)],
        ];
        if (drive && drive.serial)
            rows.push(["Serial number", drive.serial]);
        if (drive && drive.revision)
            rows.push(["Revision", drive.revision]);
        if (block.backingFile)
            rows.push(["Disk image path", block.backingFile]);
        return rows;
    }
    const fs = item.fs;
    const rows = [
        ["Volume name", item.name],
        ["Volume type", kindWords(disk, "volume")],
        ["Device node", item.block.device],
        ["Mount point", item.mounted ? item.mountPoint : "Not Mounted"],
        ["File system", item.locked ? "Encrypted" : fsName(fs.type, fs.version)],
        ["Connection", where],
        ["Writable", yes(!fs.readOnly && !fs.mountedReadOnly)],
        ["File system UUID", fs.uuid || "—"],
        ["Volume capacity", bytesText(item.size)],
    ];
    if (item.mounted) {
        rows.push(["Available space", bytesText(item.available)]);
        rows.push(["Free space", bytesText(item.free)]);
        rows.push(["Used space", bytesText(Math.max(0, item.size - item.free))]);
    }
    if (!item.locked)
        rows.push(["Owners enabled", yes(owners(fs.type))]);
    rows.push(["Is encrypted", yes(item.encrypted)]);
    if (item.block.partition) {
        rows.push(["Partition number", String(item.block.number)]);
        if (item.block.partName)
            rows.push(["Partition name", item.block.partName]);
        rows.push(["Partition type", item.block.partType || "—"]);
    }
    rows.push(["Ejectable", yes(!!disk && disk.section !== "internal")]);
    rows.push(["Solid state", yes(!!drive && drive.rotation === 0)]);
    rows.push(["S.M.A.R.T. status", smartText(drive)]);
    if (disk && disk.block)
        rows.push(["Parent disks", shortName(disk.block.device)]);
    return rows;
}

// The blocks to unmount before a disk or volume is ejected, erased or
// checked: every mounted file system on it, by its path.
export function mountedOn(all, item) {
    if (!item)
        return [];
    const parts = item.kind === "disk" ? item.parts : [item];
    return parts.filter(part => part.mounted).map(part => part.fs.path);
}
// The opened encrypted volumes on it, to lock once unmounted.
export function unlockedOn(all, item) {
    if (!item)
        return [];
    const parts = item.kind === "disk" ? item.parts : [item];
    return parts.filter(part => part.encrypted && part.inner).map(part => part.block.path);
}

// The key of the thing whose device has this short name (sda1), a disk
// first when `disks` says so; "" when there is none.
export function keyOf(all, name, disks) {
    const found = [];
    for (const disk of all.disks) {
        if (disk.block && shortName(disk.block.device) === name && !disk.logical)
            found.push({ disk: true, key: disk.key });
        for (const part of disk.parts) {
            if (shortName(part.block.device) === name)
                found.push({ disk: false, key: part.key });
        }
    }
    const wanted = found.find(entry => entry.disk === !!disks) ?? found[0];
    return wanted ? wanted.key : "";
}
