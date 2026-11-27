import { describe, expect, test } from "bun:test";
import * as Disks from "./qml/disks.mjs";

const B = "/org/freedesktop/UDisks2/block_devices/";
const D = "/org/freedesktop/UDisks2/drives/";

const block = (name: string, more: object = {}) => ({
    path: B + name, device: "/dev/" + name, drive: "", size: 0, usage: "", type: "", version: "", label: "", uuid: "",
    readOnly: false, hintIgnore: false, backing: "", mounts: [] as string[], total: 0, free: 0, available: 0,
    partitioned: false, table: "", partition: false, number: 0, partName: "", partType: "", partTable: "", offset: 0, container: false,
    loop: false, backingFile: "", encrypted: false, cleartext: "", swapActive: false, held: false, ...more,
});
const drive = (name: string, more: object = {}) => ({
    path: D + name, model: name, vendor: "", serial: "", revision: "", size: 0, bus: "", removable: false, mediaRemovable: false,
    ejectable: false, canPowerOff: false, optical: false, rotation: -1, mediaAvailable: true, smart: "unsupported", ...more,
});

// The test VM's own disk (read from UDisks2 there), a USB stick with one
// FAT volume mounted, a disk image holding an ISO, an encrypted stick
// (locked), and an empty optical drive.
const drives = [
    drive("VirtIO_Disk", { model: "VirtIO Disk", size: 42949672960 }),
    drive("stick", { vendor: "SanDisk", model: "Ultra", size: 32e9, bus: "usb", removable: true, mediaRemovable: true, canPowerOff: true, serial: "4C53" }),
    drive("vault", { vendor: "Kingston", model: "DataTraveler", size: 16e9, bus: "usb", removable: true, canPowerOff: true }),
    drive("dvd", { model: "QEMU DVD-ROM", optical: true, mediaAvailable: false, mediaRemovable: true }),
];
const blocks = [
    block("sr0", { drive: D + "dvd", size: 0 }),
    block("vda", { drive: D + "VirtIO_Disk", size: 42949672960, partitioned: true, table: "gpt" }),
    block("vda1", { drive: D + "VirtIO_Disk", size: 1073741824, usage: "filesystem", type: "vfat", version: "FAT32", label: "EFI", hintIgnore: true,
                    mounts: ["/boot"], total: 1071624192, free: 900e6, available: 900e6, partition: true, number: 1, partName: "EFI", partTable: B + "vda", offset: 1048576 }),
    block("vda2", { drive: D + "VirtIO_Disk", size: 41874882560, usage: "filesystem", type: "ext4", version: "1.0", label: "Ambrosia", uuid: "0bb60301",
                    mounts: ["/"], total: 41e9, free: 30e9, available: 28e9, partition: true, number: 2, partTable: B + "vda", offset: 1074790400 }),
    block("sdb", { drive: D + "stick", size: 32e9, partitioned: true, table: "dos" }),
    block("sdb1", { drive: D + "stick", size: 31.9e9, usage: "filesystem", type: "vfat", version: "FAT32", label: "PHOTOS",
                    mounts: ["/run/media/mina/PHOTOS"], total: 31.8e9, free: 20e9, available: 20e9, partition: true, number: 1, partTable: B + "sdb", offset: 1048576 }),
    block("sdc", { drive: D + "vault", size: 16e9, usage: "crypto", type: "crypto_LUKS", encrypted: true }),
    block("loop0", { size: 2.5e9, usage: "filesystem", type: "iso9660", label: "ARCH_202611", readOnly: true, loop: true, backingFile: "/home/mina/Downloads/arch.iso",
                     mounts: ["/run/media/mina/ARCH_202611"], total: 2.5e9, free: 0, available: 0 }),
    block("loop1", { size: 0, loop: true }),
    block("zram0", { size: 4e9, usage: "other", type: "swap", swapActive: true }),
];
const all = Disks.model(blocks, drives);

describe("sizes", () => {
    test("as a Mac writes them", () => {
        expect(Disks.sizeText(245107195904)).toBe("245.11 GB");
        expect(Disks.sizeText(999995129856)).toBe("1 TB");
        expect(Disks.sizeText(251000193024)).toBe("251 GB");
        expect(Disks.sizeText(524288000)).toBe("524.3 MB");
        expect(Disks.sizeText(207100000)).toBe("207.1 MB");
        expect(Disks.sizeText(5368709120)).toBe("5.37 GB");
        expect(Disks.sizeText(4096)).toBe("4 KB");
        expect(Disks.sizeText(0)).toBe("Zero KB");
        expect(Disks.sizeText(512)).toBe("512 bytes");
    });
    test("bytes with their thousands", () => {
        expect(Disks.bytesText(999995129856)).toBe("999,995,129,856");
        expect(Disks.bytesText(0)).toBe("0");
        expect(Disks.bytesText(1000)).toBe("1,000");
    });
});

describe("the model", () => {
    test("disks in order: internal, external, images; no empty drive, no unused loop", () => {
        expect(all.disks.map(disk => [disk.section, disk.name])).toEqual([
            ["internal", "VirtIO Disk Media"],
            ["external", "SanDisk Ultra Media"],
            ["external", "Kingston DataTraveler Media"],
            ["image", "Disk Image Media"],
        ]);
    });
    test("the EFI partition is a part, not a listed volume", () => {
        const disk = all.disks[0];
        expect(disk.parts.map(part => part.name)).toEqual(["EFI", "Ambrosia"]);
        expect(disk.volumes.map(part => part.name)).toEqual(["Ambrosia"]);
        expect(disk.system).toBe(true);
    });
    test("a disk with no partition map is one volume, under its own key", () => {
        const image = all.disks[3];
        expect(image.volumes.length).toBe(1);
        expect(image.volumes[0].key).toBe(B + "loop0#whole");
        expect(Disks.find(all, B + "loop0").kind).toBe("disk");
        expect(Disks.find(all, B + "loop0#whole").kind).toBe("volume");
    });
    test("an encrypted volume: locked until its inside is there", () => {
        const locked = Disks.find(all, B + "sdc#whole");
        expect(locked.locked).toBe(true);
        expect(locked.name).toBe("Untitled");
        const opened = Disks.model(blocks.concat([block("dm-0", { size: 15.9e9, usage: "filesystem", type: "ext4", label: "Vault", backing: B + "sdc", mounts: ["/run/media/mina/Vault"], total: 15e9, free: 14e9, available: 13e9 })]), drives);
        const vault = Disks.find(opened, B + "sdc#whole");
        expect(vault.locked).toBe(false);
        expect(vault.name).toBe("Vault");
        expect(vault.fs.path).toBe(B + "dm-0");
        expect(vault.mounted).toBe(true);
        expect(Disks.page(opened, vault, "").subtitle).toBe("USB External Physical Volume • ext4 (Encrypted)");
        expect(Disks.unlockedOn(opened, vault)).toEqual([B + "sdc"]);
        expect(Disks.mountedOn(opened, vault)).toEqual([B + "dm-0"]);
        // The inside is not a disk of its own.
        expect(opened.disks.length).toBe(4);
    });
    test("a logical volume stands alone among the internal ones", () => {
        const lvm = Disks.model([block("dm-3", { size: 100e9, usage: "filesystem", type: "xfs", label: "data", mounts: ["/srv"], total: 99e9, free: 50e9, available: 50e9 })], []);
        expect(Disks.sidebar(lvm, true, [])).toEqual([{ key: "internal", title: "Internal", rows: [
            { key: B + "dm-3", level: 0, name: "data", glyph: "volume", dim: false, eject: false, children: false, shut: false }] }]);
        expect(Disks.page(lvm, Disks.find(lvm, B + "dm-3"), "").subtitle).toBe("Logical Volume • XFS");
    });
});

describe("the sidebar", () => {
    test("only volumes", () => {
        const sections = Disks.sidebar(all, false, []);
        expect(sections.map(section => section.title)).toEqual(["Internal", "External", "Disk Images"]);
        expect(sections[0].rows.map(row => [row.level, row.name])).toEqual([[0, "Ambrosia"]]);
        expect(sections[1].rows.map(row => [row.level, row.name, row.dim, row.eject, row.glyph])).toEqual([
            [0, "PHOTOS", false, true, "volume"], [0, "Untitled", true, false, "volumeLocked"]]);
        expect(sections[2].rows.map(row => [row.level, row.name, row.eject])).toEqual([[0, "ARCH_202611", true]]);
    });
    test("all devices, and one shut", () => {
        const sections = Disks.sidebar(all, true, [B + "sdb"]);
        expect(sections[0].rows.map(row => [row.level, row.name, row.eject])).toEqual([[0, "VirtIO Disk Media", false], [1, "Ambrosia", false]]);
        expect(sections[1].rows.map(row => [row.level, row.name, row.shut])).toEqual([
            [0, "SanDisk Ultra Media", true], [0, "Kingston DataTraveler Media", false], [1, "Untitled", false]]);
    });
    test("a disk with nothing on it is listed itself", () => {
        const blank = Disks.model([block("sdd", { drive: D + "stick", size: 32e9 })], drives);
        const sections = Disks.sidebar(blank, false, []);
        expect(sections[0].rows.map(row => row.name)).toEqual(["SanDisk Ultra Media"]);
        expect(Disks.page(blank, blank.disks[0], "").subtitle).toBe("USB External Physical Disk • Uninitialized");
        expect(Disks.page(blank, blank.disks[0], "").bar.map(part => part.name)).toEqual(["Uninitialized"]);
    });
    test("what is chosen first: the volume the system runs from", () => {
        expect(Disks.first(all, false)).toBe(B + "vda2");
        expect(Disks.first(Disks.model([], []), false)).toBe("");
    });
});

describe("a page", () => {
    test("the system's volume", () => {
        const page = Disks.page(all, Disks.find(all, B + "vda2"), "Arch Linux");
        expect(page.title).toBe("Ambrosia");
        expect(page.subtitle).toBe("VirtIO Internal Physical Volume • ext4");
        expect(page.third).toBe("Arch Linux");
        expect(page.capacity).toBe("41.87 GB");
        expect(page.bar.map(part => [part.name, part.text])).toEqual([["Used", "11.87 GB"], ["Free", "30 GB"]]);
        expect(page.left).toEqual([["Mount Point:", "/"], ["Capacity:", "41.87 GB"], ["Available:", "28 GB"], ["Used:", "11.87 GB"]]);
        expect(page.right).toEqual([["Type:", "VirtIO Internal Physical Volume"], ["Owners:", "Enabled"], ["Connection:", "VirtIO"], ["Device:", "vda2"]]);
    });
    test("a disk: its parts along the bar", () => {
        const page = Disks.page(all, Disks.find(all, B + "vda"), "");
        expect(page.title).toBe("VirtIO Disk Media");
        expect(page.subtitle).toBe("VirtIO Internal Physical Disk • GUID Partition Map");
        expect(page.bar.map(part => [part.name, part.color, part.text])).toEqual([["EFI", "blue", "1.07 GB"], ["Ambrosia", "red", "41.87 GB"]]);
        expect(page.left[2]).toEqual(["Partition Map:", "GUID Partition Map"]);
        expect(page.right).toEqual([["Capacity:", "42.95 GB"], ["Child count:", "2"], ["Type:", "Disk"], ["Device:", "vda"]]);
    });
    test("a read-only image and a volume not mounted", () => {
        const image = Disks.page(all, Disks.find(all, B + "loop0#whole"), "");
        expect(image.subtitle).toBe("Disk Image Volume • ISO 9660");
        expect(image.left[0]).toEqual(["Mount Point (Read-Only):", "/run/media/mina/ARCH_202611"]);
        expect(image.right[1]).toEqual(["Owners:", "Disabled"]);
        const locked = Disks.page(all, Disks.find(all, B + "sdc#whole"), "");
        expect(locked.subtitle).toBe("USB External Physical Volume • Encrypted");
        expect(locked.left).toEqual([["Mount Point:", "Not Mounted"], ["Capacity:", "16 GB"], ["Available:", "Zero KB"], ["Used:", "--"]]);
        expect(Disks.page(all, Disks.find(all, B + "loop0"), "").left[3]).toEqual(["Image Path:", "/home/mina/Downloads/arch.iso"]);
    });
});

describe("what may be done", () => {
    const checkable = ["ext4", "vfat"];
    test("nothing to what the system runs from", () => {
        expect(Disks.can(all, Disks.find(all, B + "vda2"), checkable)).toEqual({ firstAid: false, erase: false, mount: false, mountLabel: "Unmount", eject: false, info: true });
        expect(Disks.can(all, Disks.find(all, B + "vda"), checkable).erase).toBe(false);
    });
    test("a stick's volume: all of it", () => {
        expect(Disks.can(all, Disks.find(all, B + "sdb1"), checkable)).toEqual({ firstAid: true, erase: true, mount: true, mountLabel: "Unmount", eject: true, info: true });
        expect(Disks.can(all, Disks.find(all, B + "sdb"), checkable)).toEqual({ firstAid: false, erase: true, mount: true, mountLabel: "Unmount", eject: true, info: true });
    });
    test("no First Aid without a checker, none for a locked volume; a read-only image isn't erased", () => {
        expect(Disks.can(all, Disks.find(all, B + "sdb1"), ["ext4"]).firstAid).toBe(false);
        expect(Disks.can(all, Disks.find(all, B + "sdc#whole"), checkable).firstAid).toBe(false);
        expect(Disks.can(all, Disks.find(all, B + "sdc#whole"), checkable).mountLabel).toBe("Mount");
        expect(Disks.can(all, Disks.find(all, B + "loop0#whole"), checkable).erase).toBe(false);
        expect(Disks.can(all, null, checkable).info).toBe(false);
    });
    test("nothing to a disk something else stands on, though it shows no mount point", () => {
        const checkable = ["ext4", "btrfs"];
        const second = drive("second", { model: "Data", size: 500e9 });
        // LVM: a partition and a whole disk as physical volumes, the logical volume mounted at /home.
        const lvm = Disks.model([
            block("sdb", { drive: D + "second", size: 500e9, partitioned: true, table: "gpt" }),
            block("sdb1", { drive: D + "second", size: 499e9, usage: "raid", type: "LVM2_member", partition: true, number: 1, partTable: B + "sdb", offset: 1048576, held: true }),
            block("sdc", { drive: D + "stick", size: 32e9, usage: "raid", type: "LVM2_member", held: true }),
            block("dm-1", { size: 400e9, usage: "filesystem", type: "ext4", label: "home", mounts: ["/home"], total: 399e9, free: 100e9, available: 100e9 }),
        ], drives.concat([second]));
        expect(Disks.can(lvm, Disks.find(lvm, B + "sdb"), checkable).erase).toBe(false);
        expect(Disks.can(lvm, Disks.find(lvm, B + "sdc"), checkable)).toEqual({ firstAid: false, erase: false, mount: false, mountLabel: "Mount", eject: false, info: true });
        // The same physical volume with nothing standing on it may go.
        const stale = Disks.model([block("sdb", { drive: D + "second", size: 500e9, partitioned: true, table: "gpt" }),
            block("sdb1", { drive: D + "second", size: 499e9, usage: "raid", type: "LVM2_member", partition: true, number: 1, partTable: B + "sdb", offset: 1048576 })], [second]);
        expect(Disks.can(stale, Disks.find(stale, B + "sdb"), checkable).erase).toBe(true);
        // An encrypted partition opened, a physical volume inside it.
        const sealed = Disks.model([
            block("sdb", { drive: D + "second", size: 500e9, partitioned: true, table: "gpt" }),
            block("sdb1", { drive: D + "second", size: 499e9, usage: "crypto", type: "crypto_LUKS", encrypted: true, partition: true, number: 1, partTable: B + "sdb", offset: 1048576, held: true }),
            block("dm-0", { size: 499e9, usage: "raid", type: "LVM2_member", backing: B + "sdb1", held: true }),
        ], [second]);
        expect(Disks.find(sealed, B + "sdb1").system).toBe(true);
        expect(Disks.can(sealed, Disks.find(sealed, B + "sdb1"), checkable).erase).toBe(false);
        // Btrfs over two disks, mounted from the first; a ZFS pool's member.
        const many = Disks.model([
            block("vda", { drive: D + "VirtIO_Disk", size: 40e9, usage: "filesystem", type: "btrfs", uuid: "aa-bb", label: "pool", mounts: ["/"], total: 80e9, free: 40e9, available: 40e9 }),
            block("sdb", { drive: D + "second", size: 40e9, usage: "filesystem", type: "btrfs", uuid: "aa-bb", label: "pool" }),
            block("sdc", { drive: D + "stick", size: 32e9, partitioned: true, table: "gpt" }),
            block("sdc1", { drive: D + "stick", size: 31e9, usage: "filesystem", type: "zfs_member", label: "tank", partition: true, number: 1, partTable: B + "sdc", offset: 1048576 }),
        ], drives.concat([second]));
        expect(Disks.can(many, Disks.find(many, B + "sdb#whole"), checkable)).toEqual({ firstAid: false, erase: false, mount: false, mountLabel: "Mount", eject: false, info: true });
        expect(Disks.can(many, Disks.find(many, B + "sdb"), checkable).erase).toBe(false);
        expect(Disks.can(many, Disks.find(many, B + "sdc1"), checkable).erase).toBe(false);
        expect(Disks.can(many, Disks.find(many, B + "sdc"), checkable).eject).toBe(false);
    });
    test("where a system mount is", () => {
        expect(Disks.systemMount("/")).toBe(true);
        expect(Disks.systemMount("/home")).toBe(true);
        expect(Disks.systemMount("/run/media/mina/T7")).toBe(false);
        expect(Disks.systemMount("/mnt/usb")).toBe(false);
    });
});

describe("erasing", () => {
    test("the formats this computer can make, in order", () => {
        expect(Disks.eraseFormats(["vfat", "ext4", "ext2", "nilfs2"]).map(format => format.name)).toEqual(["ext4", "MS-DOS (FAT)"]);
    });
    test("a name each file system can carry", () => {
        expect(Disks.labelFor("vfat", "My Photos 2026")).toBe("MY PHOTOS 2");
        expect(Disks.labelFor("vfat", "a.b:c")).toBe("ABC");
        expect(Disks.labelFor("ext4", "A name far too long for it")).toBe("A name far too l");
        expect(Disks.labelFor("exfat", "  Untitled ")).toBe("Untitled");
        expect(Disks.labelFor("ext4", "ééééééééé")).toBe("éééééééé");
    });
});

describe("the Info window", () => {
    test("a volume's rows", () => {
        const rows = Disks.info(all, Disks.find(all, B + "sdb1"));
        const told = Object.fromEntries(rows);
        expect(rows[0]).toEqual(["Volume name", "PHOTOS"]);
        expect(told["Volume type"]).toBe("USB External Physical Volume");
        expect(told["Device node"]).toBe("/dev/sdb1");
        expect(told["File system"]).toBe("MS-DOS (FAT32)");
        expect(told["Volume capacity"]).toBe("31,900,000,000");
        expect(told["Owners enabled"]).toBe("No");
        expect(told["Ejectable"]).toBe("Yes");
        expect(told["Parent disks"]).toBe("sdb");
    });
    test("a disk's rows", () => {
        const told = Object.fromEntries(Disks.info(all, Disks.find(all, B + "sdb")));
        expect(told["Media name"]).toBe("SanDisk Ultra Media");
        expect(told["Partition map"]).toBe("Master Boot Record");
        expect(told["Serial number"]).toBe("4C53");
    });
});
