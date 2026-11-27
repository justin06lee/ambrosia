// The calculator's arithmetic, apart from its window so it can be tested
// (calculator/calc.test.ts). A state is what has been typed since AC: a
// row of numbers and operators, and the result once = has been pressed.
// press(state, key) gives the next state and never changes the one given.
//
// A number as typed is { digits, neg, pct }: its digits kept as a string,
// so "1.50" and "0." show as typed. A result carried on into the next sum
// is { fixed, pct }: a value, shown as results are. An operator is { op }.
//
// Keys: "0" to "9", ".", "+", "−", "×", "÷", "=", "ac", "back", "neg",
// "pct".

export const operators = ["+", "−", "×", "÷"];
const most = 15; // digits a number can be typed to: what a result keeps

export function start() {
    return { tokens: [], result: null, asked: "" };
}

function isNumber(token) {
    return token !== undefined && token.op === undefined;
}

function valueOf(token) {
    if (token.fixed !== undefined)
        return token.fixed;
    const v = parseFloat(token.digits === "" || token.digits === "." ? "0" : token.digits);
    return token.neg ? -v : v;
}

// Doubles, held to fifteen figures: 0.1 + 0.2 is 0.3.
function tidy(x) {
    return Number.isFinite(x) ? Number(x.toPrecision(most)) : x;
}

// × and ÷ before + and −. A percentage alone, or in a product, is a
// hundredth; added or taken away it is a share of what stands before it
// (200 + 10% is 220), as a Mac's does.
export function evaluate(tokens) {
    let list = tokens.slice();
    while (list.length > 0 && !isNumber(list[list.length - 1]))
        list.pop();
    if (list.length === 0)
        return 0;
    const terms = [];
    let term = [list[0]];
    let sign = "+";
    for (let i = 1; i + 1 < list.length; i += 2) {
        const op = list[i].op, next = list[i + 1];
        if (op === "+" || op === "−") {
            terms.push({ sign: sign, factors: term });
            sign = op;
            term = [next];
        } else {
            term.push(op, next);
        }
    }
    terms.push({ sign: sign, factors: term });
    let sum = 0;
    for (let t = 0; t < terms.length; ++t) {
        const f = terms[t].factors;
        let v;
        if (f.length === 1 && f[0].pct && t > 0) {
            v = sum * valueOf(f[0]) / 100;
        } else {
            v = valueOf(f[0]) / (f[0].pct ? 100 : 1);
            for (let i = 1; i < f.length; i += 2) {
                const by = valueOf(f[i + 1]) / (f[i + 1].pct ? 100 : 1);
                v = f[i] === "×" ? v * by : v / by;
            }
        }
        sum = tidy(terms[t].sign === "+" ? sum + v : sum - v);
    }
    return sum;
}

function grouped(whole) {
    return whole.replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

// A result as the display shows it: thousands apart, at most fifteen
// figures, powers of ten for what is too large or too small to write out.
export function format(x) {
    if (!Number.isFinite(x))
        return "Not a number";
    x = tidy(x);
    if (x === 0)
        return "0";
    const a = Math.abs(x), minus = x < 0 ? "−" : "";
    if (a >= 1e16 || a < 1e-9)
        return minus + Number(a.toPrecision(10)).toExponential().replace("e+", "e").replace("e-", "e−");
    let s = a.toString();
    if (s.includes("e"))
        s = a.toFixed(20).replace(/0+$/, "");
    const dot = s.indexOf(".");
    return minus + (dot < 0 ? grouped(s) : grouped(s.slice(0, dot)) + s.slice(dot));
}

// The same for the clipboard: nothing a spreadsheet wouldn't read.
export function plain(x) {
    return format(x).replace(/,/g, "").replace(/−/g, "-");
}

function shown(token) {
    if (token.op !== undefined)
        return token.op;
    if (token.fixed !== undefined)
        return format(token.fixed) + (token.pct ? "%" : "");
    const dot = token.digits.indexOf(".");
    const whole = dot < 0 ? token.digits : token.digits.slice(0, dot);
    return (token.neg ? "−" : "") + grouped(whole === "" ? "0" : whole) + (dot < 0 ? "" : token.digits.slice(dot)) + (token.pct ? "%" : "");
}

export function expression(tokens) {
    return tokens.map(shown).join("");
}

// What the display says: the sum as typed; once = is pressed the result,
// under the sum that gave it.
export function display(state) {
    if (state.result !== null)
        return { main: format(state.result), top: state.asked };
    return { main: state.tokens.length === 0 ? "0" : expression(state.tokens), top: "" };
}

// What Copy takes: the result, or the number being typed.
export function copied(state) {
    if (state.result !== null)
        return plain(state.result);
    const last = state.tokens[state.tokens.length - 1];
    return isNumber(last) ? plain(valueOf(last) / (last.pct ? 100 : 1)) : "0";
}

// The text of a paste as a state to go on from, or null when it is no number.
export function pasted(state, text) {
    const cleaned = text.trim().replace(/,/g, "").replace(/−/g, "-");
    if (!/^-?(\d+\.?\d*|\.\d+)(e[-+]?\d+)?$/i.test(cleaned))
        return null;
    const v = Number(cleaned);
    if (!Number.isFinite(v))
        return null;
    const tokens = state.result !== null ? [] : state.tokens.slice();
    if (isNumber(tokens[tokens.length - 1]))
        tokens.pop();
    tokens.push({ fixed: tidy(v), pct: false });
    return { tokens: tokens, result: null, asked: "" };
}

export function press(state, key) {
    if (key === "ac")
        return start();
    let tokens = state.tokens.slice();
    const done = state.result !== null;
    const carried = () => [{ fixed: Number.isFinite(state.result) ? state.result : 0, pct: false }];
    const next = (list) => ({ tokens: list, result: null, asked: "" });
    const last = tokens[tokens.length - 1];

    if (/^[0-9]$/.test(key) || key === ".") {
        if (done)
            tokens = [];
        const at = tokens[tokens.length - 1];
        if (isNumber(at)) {
            // A percentage takes no more digits; a number pasted or carried
            // on gives way to the one now typed.
            if (at.pct)
                return state;
            let digits = at.fixed !== undefined ? "" : at.digits;
            const neg = at.fixed !== undefined ? false : at.neg;
            if (key === ".") {
                if (digits.includes("."))
                    return state;
                digits = (digits === "" ? "0" : digits) + ".";
            } else if (digits === "0" || digits === "") {
                digits = key;
            } else if (digits.replace(".", "").length >= most) {
                return state;
            } else {
                digits += key;
            }
            tokens[tokens.length - 1] = { digits: digits, neg: neg, pct: false };
        } else {
            tokens.push({ digits: key === "." ? "0." : key, neg: false, pct: false });
        }
        return next(tokens);
    }
    if (operators.includes(key)) {
        if (done)
            tokens = carried();
        if (tokens.length === 0)
            tokens.push({ digits: "0", neg: false, pct: false });
        if (isNumber(tokens[tokens.length - 1]))
            tokens.push({ op: key });
        else
            tokens[tokens.length - 1] = { op: key };
        return next(tokens);
    }
    if (key === "=") {
        if (done || tokens.length === 0)
            return state;
        if (!isNumber(last))
            tokens.pop();
        return { tokens: tokens, result: evaluate(tokens), asked: expression(tokens) };
    }
    if (key === "back") {
        if (done || tokens.length === 0)
            return state;
        if (!isNumber(last) || last.fixed !== undefined) {
            tokens.pop();
        } else if (last.pct) {
            tokens[tokens.length - 1] = { digits: last.digits, neg: last.neg, pct: false };
        } else {
            const digits = last.digits.slice(0, -1);
            if (digits === "")
                tokens.pop();
            else
                tokens[tokens.length - 1] = { digits: digits, neg: last.neg, pct: false };
        }
        return next(tokens);
    }
    if (key === "neg" || key === "pct") {
        if (done)
            tokens = carried();
        const at = tokens[tokens.length - 1];
        if (!isNumber(at))
            return state;
        if (key === "pct") {
            if (at.pct)
                return state;
            tokens[tokens.length - 1] = Object.assign({}, at, { pct: true });
        } else if (at.fixed !== undefined) {
            tokens[tokens.length - 1] = { fixed: -at.fixed, pct: at.pct };
        } else {
            tokens[tokens.length - 1] = { digits: at.digits, neg: !at.neg, pct: at.pct };
        }
        return next(tokens);
    }
    return state;
}
