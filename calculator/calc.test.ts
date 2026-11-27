import { expect, test } from "bun:test";
// @ts-ignore: plain JavaScript, shared with the QML window.
import * as Calc from "./qml/calc.mjs";

/** Presses keys one after another: "2+3×4=" and the names in brackets ("[ac]"). */
function typed(keys: string, from = Calc.start()) {
  let state = from;
  for (const key of keys.match(/\[[a-z]+\]|./g) ?? [])
    state = Calc.press(state, key.startsWith("[") ? key.slice(1, -1) : key);
  return state;
}
const main = (keys: string) => Calc.display(typed(keys)).main;

test("× and ÷ come before + and −", () => {
  expect(main("2+3×4=")).toBe("14");
  expect(main("10−6÷3=")).toBe("8");
  expect(main("2×3+4×5=")).toBe("26");
});

test("decimals are held to fifteen figures", () => {
  expect(main(".1+.2=")).toBe("0.3");
  expect(main("1÷3=")).toBe("0.333333333333333");
  expect(main("0.1×3=")).toBe("0.3");
});

test("the display shows the sum as typed, then the result under it", () => {
  expect(main("12")).toBe("12");
  expect(main("1234.50")).toBe("1,234.50");
  expect(main("2+3×")).toBe("2+3×");
  expect(main("0.")).toBe("0.");
  const done = Calc.display(typed("1000×1000="));
  expect(done.main).toBe("1,000,000");
  expect(done.top).toBe("1,000×1,000");
});

test("a percentage is a hundredth, or a share of what it is added to", () => {
  expect(main("50[pct]=")).toBe("0.5");
  expect(main("200+10[pct]=")).toBe("220");
  expect(main("200−10[pct]=")).toBe("180");
  expect(main("200×10[pct]=")).toBe("20");
  expect(main("200+10[pct]")).toBe("200+10%");
});

test("an operator typed twice is the second; a trailing one is dropped", () => {
  expect(main("2+×3=")).toBe("6");
  expect(main("2+3+=")).toBe("5");
  expect(main("×5=")).toBe("0");
});

test("a result is carried into the next sum, or replaced by a digit", () => {
  expect(main("2+3=×4=")).toBe("20");
  expect(main("2+3=7")).toBe("7");
  expect(main("2+3=[neg]")).toBe("−5");
  expect(main("2+3==")).toBe("5");
});

test("delete takes back one key", () => {
  expect(main("123[back]")).toBe("12");
  expect(main("12+[back]")).toBe("12");
  expect(main("12+3[back]")).toBe("12+");
  expect(main("5[pct][back]")).toBe("5");
  expect(main("1[back]")).toBe("0");
  expect(main("1[back][back]")).toBe("0");
});

test("the sign", () => {
  expect(main("5[neg]")).toBe("−5");
  expect(main("5[neg][neg]")).toBe("5");
  expect(main("8×3[neg]=")).toBe("−24");
});

test("what can't be", () => {
  expect(main("1÷0=")).toBe("Not a number");
  expect(main("0÷0=")).toBe("Not a number");
  expect(main("1÷0=+2=")).toBe("2");
});

test("the very large and the very small", () => {
  expect(main("9999999999×9999999999=")).toBe("9.999999998e19");
  expect(main("1÷9999999999=")).toBe("1e−10");
  expect(main("1÷8000000=")).toBe("0.000000125");
  expect(Calc.format(1.5e-12)).toBe("1.5e−12");
  expect(Calc.format(-1234567.25)).toBe("−1,234,567.25");
});

test("a number takes fifteen digits and one point", () => {
  expect(main("12345678901234567890")).toBe("123,456,789,012,345");
  expect(main("1.2.3")).toBe("1.23");
  expect(main("007")).toBe("7");
});

test("copy and paste", () => {
  expect(Calc.copied(typed("1000×1000="))).toBe("1000000");
  expect(Calc.copied(typed("12.5"))).toBe("12.5");
  expect(Calc.copied(typed("5[neg]"))).toBe("-5");
  const state = Calc.pasted(typed("2+"), " 1,250.5 ");
  expect(Calc.display(state).main).toBe("2+1,250.5");
  expect(Calc.display(Calc.press(state, "=")).main).toBe("1,252.5");
  expect(Calc.pasted(typed("2+"), "two")).toBeNull();
  // A digit typed after a paste starts the number again.
  expect(Calc.display(typed("7", state)).main).toBe("2+7");
  expect(Calc.display(typed(".5", state)).main).toBe("2+0.5");
});

test("AC clears everything", () => {
  expect(main("2+3[ac]")).toBe("0");
  expect(main("2+3=[ac]4")).toBe("4");
});
