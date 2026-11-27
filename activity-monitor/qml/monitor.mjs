// Activity Monitor's arithmetic and words, apart from the windows so bun can
// test it (activity-monitor/monitor.test.ts): what each tab lists, how a
// number is written as a Mac writes it, which processes a view keeps and in
// what order, and what the panels under the table make of the kernel's
// counters. Plain JavaScript that QML's engine runs too: no object spread,
// no ??=.

// The tabs, in a Mac's order. A column's `width` is its room in points
// (the 17 between two columns included, as measured from macOS 27's); the
// name column takes what the others leave (PID is wider than a Mac's 57:
// Linux's ids run to seven digits). `kind` says how its values are
// written and sorted; `first` is the column a tab opens sorted by.
export const tabs = [
    { key: "cpu", title: "CPU", name: "Process Name", first: "cpu", columns: [
        { key: "cpu", title: "% CPU", width: 92, kind: "percent" },
        { key: "cpuTime", title: "CPU Time", width: 87, kind: "time" },
        { key: "threads", title: "Threads", width: 77, kind: "count" },
        { key: "wakeups", title: "Idle Wake Ups", width: 115, kind: "count" },
        { key: "pid", title: "PID", width: 74, kind: "plain" },
        { key: "user", title: "User", width: 94, kind: "text" },
    ] },
    { key: "memory", title: "Memory", name: "Process Name", first: "memory", columns: [
        { key: "memory", title: "Memory", width: 100, kind: "bytes" },
        { key: "threads", title: "Threads", width: 77, kind: "count" },
        { key: "pid", title: "PID", width: 74, kind: "plain" },
        { key: "user", title: "User", width: 94, kind: "text" },
    ] },
    { key: "energy", title: "Energy", name: "App Name", first: "energy", columns: [
        { key: "energy", title: "Energy Impact", width: 117, kind: "percent" },
        { key: "sleep", title: "Preventing Sleep", width: 124, kind: "yesNo" },
        { key: "user", title: "User", width: 94, kind: "text" },
    ] },
    { key: "disk", title: "Disk", name: "Process Name", first: "written", columns: [
        { key: "written", title: "Bytes Written", width: 109, kind: "bytes" },
        { key: "read", title: "Bytes Read", width: 109, kind: "bytes" },
        { key: "pid", title: "PID", width: 74, kind: "plain" },
        { key: "user", title: "User", width: 94, kind: "text" },
    ] },
    { key: "network", title: "Network", name: "Process Name", first: "sent", columns: [
        { key: "sent", title: "Sent Bytes", width: 97, kind: "bytes" },
        { key: "received", title: "Rcvd Bytes", width: 97, kind: "bytes" },
        { key: "sentPackets", title: "Sent Packets", width: 97, kind: "count" },
        { key: "receivedPackets", title: "Rcvd Packets", width: 97, kind: "count" },
        { key: "pid", title: "PID", width: 74, kind: "plain" },
        { key: "user", title: "User", width: 94, kind: "text" },
    ] },
];

export function tab(key) {
    return tabs.find(t => t.key === key) || tabs[0];
}

// Which processes a view lists, in the View menu's order and words.
export const categories = [
    { key: "all", title: "All Processes" },
    { key: "mine", title: "My Processes" },
    { key: "system", title: "System Processes" },
    { key: "others", title: "Other Users’ Processes" },
    { key: "active", title: "Active Processes" },
    { key: "inactive", title: "Inactive Processes" },
    { key: "selected", title: "Selected Processes" },
];

export function categoryTitle(key) {
    const found = categories.find(c => c.key === key);
    return found ? found.title : "";
}

// 1234567 as 1,234,567.
export function count(n) {
    if (n === undefined || n === null || n < 0 || !isFinite(n))
        return "";
    const digits = String(Math.round(n));
    let out = "";
    for (let i = 0; i < digits.length; ++i) {
        if (i > 0 && (digits.length - i) % 3 === 0)
            out += ",";
        out += digits[i];
    }
    return out;
}

// A size as a Mac writes one: whole bytes and KB, MB to a tenth, GB and
// more to a hundredth, each unit 1024 of the one before.
export function bytes(n) {
    if (n === undefined || n === null || n < 0 || !isFinite(n))
        return "";
    if (n < 1024)
        return n === 1 ? "1 byte" : Math.round(n) + " bytes";
    const units = ["KB", "MB", "GB", "TB", "PB"];
    let value = n / 1024, unit = 0;
    // 1023.96 MB would be written 1024.0 MB: it is 1.00 GB.
    while (unit < units.length - 1 && Number(value.toFixed(unit === 0 ? 0 : unit === 1 ? 1 : 2)) >= 1024) {
        value /= 1024;
        ++unit;
    }
    return value.toFixed(unit === 0 ? 0 : unit === 1 ? 1 : 2) + " " + units[unit];
}

// What goes over the network in a second, in bits as macOS 27 writes it:
// 303.94 kb/s, 9.00 Mb/s.
export function bitRate(bytesPerSecond) {
    if (bytesPerSecond === undefined || bytesPerSecond === null || bytesPerSecond < 0 || !isFinite(bytesPerSecond))
        return "";
    const units = ["kb/s", "Mb/s", "Gb/s"];
    let value = bytesPerSecond * 8 / 1000, unit = 0;
    while (unit < units.length - 1 && Number(value.toFixed(2)) >= 1000) {
        value /= 1000;
        ++unit;
    }
    return value.toFixed(2) + " " + units[unit];
}

// Processor time: 41.47, 1:05.03, 3:18:23.44.
export function cpuTime(seconds) {
    if (seconds === undefined || seconds === null || seconds < 0 || !isFinite(seconds))
        return "";
    const hundredths = Math.round(seconds * 100);
    const h = Math.floor(hundredths / 360000);
    const m = Math.floor(hundredths / 6000) % 60;
    const s = Math.floor(hundredths / 100) % 60;
    const rest = hundredths % 100;
    const two = (v) => (v < 10 ? "0" : "") + v;
    if (h > 0)
        return h + ":" + two(m) + ":" + two(s) + "." + two(rest);
    if (m > 0)
        return m + ":" + two(s) + "." + two(rest);
    return s + "." + two(rest);
}

export function percent(value, digits) {
    if (value === undefined || value === null || value < 0 || !isFinite(value))
        return "";
    return value.toFixed(digits === undefined ? 1 : digits);
}

// A cell's words. A value that isn't known (the first sample has no rates;
// another user's process doesn't say what it read) leaves the cell empty,
// as a Mac's does.
export function cell(process, column) {
    const value = process[column.key];
    switch (column.kind) {
    case "percent": return percent(value, 1);
    case "time": return cpuTime(value);
    case "count": return count(value);
    case "bytes": return bytes(value);
    case "yesNo": return value === undefined || value === null ? "" : value ? "Yes" : "No";
    case "plain": return value === undefined || value === null || value < 0 ? "" : String(value);
    default: return value === undefined || value === null ? "" : String(value);
    }
}

// Whether a column's values are words (set from the left) or numbers (from
// the right); Yes and No sit in the middle.
export function alignment(column) {
    return column.kind === "text" ? "left" : column.kind === "yesNo" ? "center" : "right";
}

// An energy impact as a Mac reckons one: the processor's share plus what
// waking it costs (two ten-thousandths of a second a time).
export function energy(cpuPercent, wakeupsPerSecond) {
    if (cpuPercent === undefined || cpuPercent === null || cpuPercent < 0)
        return -1;
    const wakes = wakeupsPerSecond > 0 ? wakeupsPerSecond : 0;
    return cpuPercent + wakes * 0.02;
}

// The processes a view keeps. `me` is the user's id; `chosen` the process
// ids picked when Selected Processes was asked for.
export function kept(processes, category, me, chosen) {
    switch (category) {
    case "mine": return processes.filter(p => p.uid === me);
    case "system": return processes.filter(p => p.uid === 0);
    case "others": return processes.filter(p => p.uid !== 0 && p.uid !== me);
    case "active": return processes.filter(p => p.active);
    case "inactive": return processes.filter(p => !p.active);
    case "selected": return processes.filter(p => (chosen || []).indexOf(p.pid) >= 0);
    default: return processes.slice();
    }
}

// Those whose name holds what's in the search field, in either case.
export function found(processes, text) {
    const want = (text || "").trim().toLowerCase();
    if (want === "")
        return processes;
    return processes.filter(p => String(p.name).toLowerCase().indexOf(want) >= 0);
}

function unknown(value) {
    return value === undefined || value === null || (typeof value === "number" && value < 0);
}

// In order by one column. Names and users go by the alphabet in either
// case; what isn't known goes last whichever way the order runs; two alike
// keep to their process ids, so rows don't trade places between samples.
export function sorted(processes, key, descending) {
    const text = key === "name" || key === "user";
    const out = processes.slice();
    out.sort((a, b) => {
        const x = a[key], y = b[key];
        const ux = unknown(x), uy = unknown(y);
        if (ux !== uy)
            return ux ? 1 : -1;
        let order = 0;
        if (!ux) {
            if (text)
                order = String(x).toLowerCase() < String(y).toLowerCase() ? -1 : String(x).toLowerCase() > String(y).toLowerCase() ? 1 : 0;
            else
                order = (x === y) ? 0 : (x < y ? -1 : 1);
        }
        if (order !== 0)
            return descending ? -order : order;
        return a.pid - b.pid;
    });
    return out;
}

// What a view lists: kept by its category, then by the search, in order.
export function listed(processes, view) {
    return sorted(found(kept(processes, view.category, view.me, view.chosen), view.search), view.sortKey, view.descending);
}

// The processor's shares between two readings of /proc/stat's first line
// (user, nice, system, idle, iowait, irq, softirq, steal): a Mac's User,
// System and Idle, of a hundred.
export function cpuShares(before, now) {
    if (!before || !now || before.length < 4 || now.length < 4)
        return { user: 0, system: 0, idle: 100 };
    const d = (i) => Math.max(0, (now[i] || 0) - (before[i] || 0));
    const user = d(0) + d(1);
    const system = d(2) + d(5) + d(6) + d(7);
    const idle = d(3) + d(4);
    const total = user + system + idle;
    if (total <= 0)
        return { user: 0, system: 0, idle: 100 };
    return { user: 100 * user / total, system: 100 * system / total, idle: 100 * idle / total };
}

// Memory as a Mac's panel has it, from /proc/meminfo's numbers (in kB, the
// kernel's names) and `ZramUsed` (what zram holds, kB). In bytes. Used is
// what couldn't be had back without swapping; of it, wired is the kernel's
// own and what is locked in, compressed what zswap and zram hold, and the
// rest is apps'. Pressure is the share that isn't available, as a Mac
// draws it, and turns to a warning as little is left or the kernel says
// work stalls for memory (`some` and `full`: /proc/pressure/memory's ten
// second averages).
export function memory(info, some, full) {
    const kb = (name) => (info && info[name] > 0 ? info[name] : 0);
    const total = kb("MemTotal");
    const available = Math.min(total, kb("MemAvailable"));
    const used = total - available;
    const compressed = Math.min(used, kb("Zswap") + kb("ZramUsed"));
    const wired = Math.min(used - compressed, kb("SUnreclaim") + kb("KernelStack") + kb("PageTables") + kb("Percpu") + kb("Mlocked"));
    const share = total > 0 ? used / total : 0;
    let level = "normal";
    if (share > 0.95 || full >= 10)
        level = "critical";
    else if (share > 0.85 || some >= 10)
        level = "warning";
    return {
        physical: total * 1024,
        used: used * 1024,
        cached: Math.max(0, kb("Cached") + kb("Buffers") + kb("SReclaimable") - kb("Shmem")) * 1024,
        swapUsed: Math.max(0, kb("SwapTotal") - kb("SwapFree")) * 1024,
        app: (used - wired - compressed) * 1024,
        wired: wired * 1024,
        compressed: compressed * 1024,
        pressure: share,
        level: level,
    };
}

// How fast a counter runs between two readings, never backwards (a disk
// taken out, an interface gone).
export function rate(before, now, seconds) {
    if (before === undefined || before === null || now === undefined || now === null || !(seconds > 0))
        return 0;
    return Math.max(0, (now - before) / seconds);
}

// A history with one more reading, the oldest let go past `limit`.
export function pushed(history, value, limit) {
    const out = history.concat([value]);
    return out.length > limit ? out.slice(out.length - limit) : out;
}

// The top of a graph: the largest reading, but never under `least` (a quiet
// disk's line stays flat rather than drawing its noise tall).
export function ceiling(history, least) {
    let top = least > 0 ? least : 1;
    for (const value of history) {
        const v = typeof value === "number" ? value : Math.max(value.up || 0, value.down || 0);
        if (v > top)
            top = v;
    }
    return top;
}
