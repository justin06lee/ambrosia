import { expect, test } from "bun:test";
// @ts-ignore: a plain module, shared with the QML
import * as Monitor from "./qml/monitor.mjs";

test("numbers as a Mac's Activity Monitor writes them", () => {
    expect(Monitor.count(21993925)).toBe("21,993,925");
    expect(Monitor.count(815)).toBe("815");
    expect(Monitor.count(1000)).toBe("1,000");
    expect(Monitor.count(-1)).toBe("");

    expect(Monitor.bytes(0)).toBe("0 bytes");
    expect(Monitor.bytes(1)).toBe("1 byte");
    expect(Monitor.bytes(1023)).toBe("1023 bytes");
    expect(Monitor.bytes(512 * 1024)).toBe("512 KB");
    expect(Monitor.bytes(252.3 * 1024 * 1024)).toBe("252.3 MB");
    expect(Monitor.bytes(16 * 1024 ** 3)).toBe("16.00 GB");
    expect(Monitor.bytes(490.01 * 1024 ** 3)).toBe("490.01 GB");
    // Never 1024.0 MB.
    expect(Monitor.bytes(1024 ** 3 - 1)).toBe("1.00 GB");
    expect(Monitor.bytes(-1)).toBe("");

    expect(Monitor.bitRate(303940 / 8)).toBe("303.94 kb/s");
    expect(Monitor.bitRate(9e6 / 8)).toBe("9.00 Mb/s");
    expect(Monitor.bitRate(0)).toBe("0.00 kb/s");

    expect(Monitor.cpuTime(41.47)).toBe("41.47");
    expect(Monitor.cpuTime(65.03)).toBe("1:05.03");
    expect(Monitor.cpuTime(3 * 3600 + 18 * 60 + 23.44)).toBe("3:18:23.44");
    expect(Monitor.cpuTime(0)).toBe("0.00");

    expect(Monitor.percent(41.4699)).toBe("41.5");
    expect(Monitor.percent(21.8, 2)).toBe("21.80");
    expect(Monitor.percent(-1)).toBe("");
});

test("each tab's columns, and a cell's words", () => {
    expect(Monitor.tabs.map((tab: any) => tab.title)).toEqual(["CPU", "Memory", "Energy", "Disk", "Network"]);
    for (const tab of Monitor.tabs) {
        // A tab opens sorted by a column it has.
        expect(tab.columns.some((column: any) => column.key === tab.first)).toBe(true);
        expect(tab.columns[tab.columns.length - 1].key).toBe("user");
    }
    expect(Monitor.tab("energy").name).toBe("App Name");
    expect(Monitor.tab("nothing").key).toBe("cpu");

    const process = { pid: 722, name: "Files", user: "mina", cpu: 3.14159, cpuTime: 75.5, threads: 1234, memory: 93.2 * 1024 * 1024, sleep: true, read: -1 };
    const cpu = Monitor.tab("cpu").columns;
    expect(cpu.map((column: any) => Monitor.cell(process, column))).toEqual(["3.1", "1:15.50", "1,234", "", "722", "mina"]);
    expect(Monitor.cell(process, Monitor.tab("memory").columns[0])).toBe("93.2 MB");
    expect(Monitor.cell(process, Monitor.tab("energy").columns[1])).toBe("Yes");
    // What a process doesn't say stays empty.
    expect(Monitor.cell(process, Monitor.tab("disk").columns[1])).toBe("");
    expect(Monitor.alignment(cpu[0])).toBe("right");
    expect(Monitor.alignment(cpu[5])).toBe("left");
    expect(Monitor.alignment(Monitor.tab("energy").columns[1])).toBe("center");
});

const some = [
    { pid: 1, uid: 0, name: "systemd", user: "root", cpu: 0, active: false, memory: 5 },
    { pid: 40, uid: 1000, name: "Files", user: "mina", cpu: 2, active: true, memory: 300 },
    { pid: 41, uid: 1000, name: "ambrosia-shell", user: "mina", cpu: 9, active: true, memory: 200 },
    { pid: 50, uid: 970, name: "sddm-helper", user: "sddm", cpu: 0, active: false, memory: -1 },
    { pid: 60, uid: 1000, name: "bash", user: "mina", cpu: 0, active: false, memory: 200 },
];
const pids = (list: any[]) => list.map(p => p.pid);

test("what each view keeps", () => {
    expect(pids(Monitor.kept(some, "all", 1000, []))).toEqual([1, 40, 41, 50, 60]);
    expect(pids(Monitor.kept(some, "mine", 1000, []))).toEqual([40, 41, 60]);
    expect(pids(Monitor.kept(some, "system", 1000, []))).toEqual([1]);
    expect(pids(Monitor.kept(some, "others", 1000, []))).toEqual([50]);
    expect(pids(Monitor.kept(some, "active", 1000, []))).toEqual([40, 41]);
    expect(pids(Monitor.kept(some, "inactive", 1000, []))).toEqual([1, 50, 60]);
    expect(pids(Monitor.kept(some, "selected", 1000, [60, 1]))).toEqual([1, 60]);
    expect(pids(Monitor.found(some, "  FiL "))).toEqual([40]);
    expect(pids(Monitor.found(some, ""))).toEqual([1, 40, 41, 50, 60]);
    expect(Monitor.categoryTitle("mine")).toBe("My Processes");
});

test("the order of the rows", () => {
    expect(pids(Monitor.sorted(some, "cpu", true))).toEqual([41, 40, 1, 50, 60]);
    expect(pids(Monitor.sorted(some, "cpu", false))).toEqual([1, 50, 60, 40, 41]);
    // Names by the alphabet, capitals among the rest.
    expect(pids(Monitor.sorted(some, "name", false))).toEqual([41, 60, 40, 50, 1]);
    // What isn't known goes last either way; two alike keep to their ids.
    expect(pids(Monitor.sorted(some, "memory", true))).toEqual([40, 41, 60, 1, 50]);
    expect(pids(Monitor.sorted(some, "memory", false))).toEqual([1, 41, 60, 40, 50]);
    expect(pids(Monitor.listed(some, { category: "mine", me: 1000, chosen: [], search: "a", sortKey: "cpu", descending: true }))).toEqual([41, 60]);
    // The list given isn't touched.
    expect(pids(some)).toEqual([1, 40, 41, 50, 60]);
});

test("the processor's shares", () => {
    const before = [1000, 10, 500, 8000, 100, 5, 5, 0];
    const now = [1300, 10, 600, 8580, 120, 0, 5, 0].map((v, i) => (i === 5 ? 5 : v));
    const shares = Monitor.cpuShares(before, now);
    expect(shares.user).toBeCloseTo(30, 5);
    expect(shares.system).toBeCloseTo(10, 5);
    expect(shares.idle).toBeCloseTo(60, 5);
    expect(Monitor.cpuShares(null, now)).toEqual({ user: 0, system: 0, idle: 100 });
    expect(Monitor.cpuShares(now, now)).toEqual({ user: 0, system: 0, idle: 100 });
});

test("memory, from the kernel's numbers", () => {
    const GB = 1024 * 1024; // kB
    const m = Monitor.memory({
        MemTotal: 16 * GB, MemAvailable: 6 * GB, Cached: 4 * GB, Buffers: 0.5 * GB, SReclaimable: 0.5 * GB, Shmem: 1 * GB,
        SwapTotal: 8 * GB, SwapFree: 7 * GB, SUnreclaim: 0.5 * GB, KernelStack: 0.1 * GB, PageTables: 0.2 * GB, Percpu: 0.1 * GB, Mlocked: 0.1 * GB,
        Zswap: 0.5 * GB, ZramUsed: 0.5 * GB,
    }, 0, 0);
    expect(Monitor.bytes(m.physical)).toBe("16.00 GB");
    expect(Monitor.bytes(m.used)).toBe("10.00 GB");
    expect(Monitor.bytes(m.cached)).toBe("4.00 GB");
    expect(Monitor.bytes(m.swapUsed)).toBe("1.00 GB");
    expect(Monitor.bytes(m.wired)).toBe("1.00 GB");
    expect(Monitor.bytes(m.compressed)).toBe("1.00 GB");
    expect(Monitor.bytes(m.app)).toBe("8.00 GB");
    // The three are what is used, as on a Mac.
    expect(m.app + m.wired + m.compressed).toBe(m.used);
    expect(m.pressure).toBeCloseTo(10 / 16, 6);
    expect(m.level).toBe("normal");
    expect(Monitor.memory({ MemTotal: 100, MemAvailable: 10 }, 0, 0).level).toBe("warning");
    expect(Monitor.memory({ MemTotal: 100, MemAvailable: 2 }, 0, 0).level).toBe("critical");
    expect(Monitor.memory({ MemTotal: 100, MemAvailable: 60 }, 25, 0).level).toBe("warning");
    expect(Monitor.memory({ MemTotal: 100, MemAvailable: 60 }, 40, 12).level).toBe("critical");
    expect(Monitor.memory({}, 0, 0).physical).toBe(0);
});

test("rates, histories and a graph's top", () => {
    expect(Monitor.rate(1000, 1500, 5)).toBe(100);
    expect(Monitor.rate(1500, 1000, 5)).toBe(0);
    expect(Monitor.rate(undefined, 1000, 5)).toBe(0);
    expect(Monitor.pushed([1, 2, 3], 4, 3)).toEqual([2, 3, 4]);
    expect(Monitor.pushed([], 4, 3)).toEqual([4]);
    expect(Monitor.ceiling([1, 9, 3], 5)).toBe(9);
    expect(Monitor.ceiling([1, 2], 5)).toBe(5);
    expect(Monitor.ceiling([{ up: 2, down: 30 }], 5)).toBe(30);
    expect(Monitor.energy(10, 100)).toBe(12);
    expect(Monitor.energy(-1, 100)).toBe(-1);
});
