// Oracle runner: loads compiled .wasm files and prints expected values.
// Used to generate / verify ACL2 test expected values.
// Usage: node check-all.mjs

import { readFileSync } from 'fs';
import { tmpdir } from 'os';

const tmp = process.env.TMPDIR || tmpdir();

async function load(name) {
  const buf = readFileSync(`${tmp}/${name}.wasm`);
  const { instance } = await WebAssembly.instantiate(buf);
  return instance.exports;
}

function check(label, actual, expected) {
  const pass = actual === expected;
  const tag = pass ? 'PASS' : 'FAIL';
  console.log(`  ${tag}: ${label} = ${actual}` + (pass ? '' : ` (expected ${expected})`));
  return pass;
}

let failures = 0;

// --- GCD ---
const gcd = await load('gcd');
[
  [48, 18, 6],
  [35, 14, 7],
  [1, 1, 1],
  [17, 0, 17],
  [0, 5, 5],
].forEach(([a, b, exp]) => {
  if (!check(`gcd(${a},${b})`, gcd.gcd(a, b), exp)) failures++;
});

// --- sum_array ---
const sum = await load('sum_array');
if (!check('sum_array(0,5)', sum.sum_array(0, 5), 150)) failures++;

// --- hash ---
const hash = await load('hash');
if (!check('djb2("Hi",0,2)', hash.djb2(0, 2), 5862390)) failures++;

// --- collatz ---
const col = await load('collatz');
[
  [6, 8],
  [27, 111],
  [1, 0],
].forEach(([n, exp]) => {
  if (!check(`collatz(${n})`, col.collatz(n), exp)) failures++;
});

// --- is_prime ---
const prime = await load('is_prime');
[
  [1, 0], [2, 1], [3, 1], [4, 0], [7, 1],
  [12, 0], [97, 1], [100, 0],
].forEach(([n, exp]) => {
  if (!check(`is_prime(${n})`, prime.is_prime(n), exp)) failures++;
});

// --- packed_mem ---
const pm = await load('packed_mem');
[
  ['load8_u(0)', pm.load8_u(0), 171],
  ['load8_u(1)', pm.load8_u(1), 205],
  ['load8_s(0)', pm.load8_s(0), -85],
  ['load8_s(3)', pm.load8_s(3), 18],
  ['load16_u(0)', pm.load16_u(0), 52651],
  ['load16_u(2)', pm.load16_u(2), 4847],
  ['load16_s(0)', pm.load16_s(0), -12885],
  ['load16_s(2)', pm.load16_s(2), 4847],
  ['store8(16,0x1FF)', pm.store8_load(16, 0x1FF), 255],
  ['store16(20,0xDEADBEEF)', pm.store16_load(20, 0xDEADBEEF), 48879],
].forEach(([label, actual, expected]) => {
  if (!check(label, actual, expected)) failures++;
});

// --- packed_mem_i64 ---
const pm64 = await load('packed_mem_i64');
[
  ['i64_load8_u(0)', pm64.i64_load8_u(0), 171n],
  ['i64_load8_s(0)', pm64.i64_load8_s(0), -85n],
  ['i64_load8_s(3)', pm64.i64_load8_s(3), 18n],
  ['i64_load16_u(0)', pm64.i64_load16_u(0), 52651n],
  ['i64_load16_s(0)', pm64.i64_load16_s(0), -12885n],
  ['i64_load32_u(0)', pm64.i64_load32_u(0), 317705643n],
  ['i64_load32_s(0)', pm64.i64_load32_s(0), 317705643n],
  ['i64_load32_s(4)', pm64.i64_load32_s(4), -1703389644n],
  ['i64_store8(16,0x1FF)', pm64.i64_store8_load(16, 0x1FFn), 255n],
  ['i64_store16(20,0xDEADBEEF)', pm64.i64_store16_load(20, 0xDEADBEEFn), 48879n],
  ['i64_store32(24,0x123456789ABCDEF)', pm64.i64_store32_load(24, 0x123456789ABCDEFn), 2309737967n],
].forEach(([label, actual, expected]) => {
  // BigInt comparison
  const pass = actual === expected;
  const tag = pass ? 'PASS' : 'FAIL';
  console.log(`  ${tag}: ${label} = ${actual}` + (pass ? '' : ` (expected ${expected})`));
  if (!pass) failures++;
});

// --- call_indirect (M7b) ---
const ci = await load('call_indirect');
[
  ['dispatch(5,0)=double(5)', ci.dispatch(5, 0), 10],
  ['dispatch(42,1)=inc(42)', ci.dispatch(42, 1), 43],
  ['dispatch(3,0)=double(3)', ci.dispatch(3, 0), 6],
  ['dispatch(3,1)=inc(3)', ci.dispatch(3, 1), 4],
].forEach(([label, actual, expected]) => {
  if (!check(label, actual, expected)) failures++;
});
// OOB trap test
try {
  ci.dispatch(5, 99);
  console.log('  FAIL: dispatch(5,99) should have trapped');
  failures++;
} catch (e) {
  console.log('  PASS: dispatch(5,99) → trap');
}

// --- float_ops (M7a, M8.8, M8.9) ---
const fo = await load('float_ops');
[
  ['f64_add(1.5,2.5)', fo.f64_add(1.5, 2.5), 4],
  ['f64_sub(10,3)', fo.f64_sub(10, 3), 7],
  ['f64_mul(7,6)', fo.f64_mul(7, 6), 42],
  ['f64_div(22,7)', fo.f64_div(22, 7), 22/7],
  ['f64_neg(42)', fo.f64_neg(42), -42],
  ['f64_abs(-100)', fo.f64_abs(-100), 100],
  ['f64_ceil(1.5)', fo.f64_ceil(1.5), 2],
  ['f64_floor(3.5)', fo.f64_floor(3.5), 3],
  ['f64_eq(3,3)', fo.f64_eq(3, 3), 1],
  ['f64_eq(3,4)', fo.f64_eq(3, 4), 0],
  ['f64_lt(2,5)', fo.f64_lt(2, 5), 1],
  ['f32_add(1.5,2.5)', fo.f32_add(1.5, 2.5), 4],
  ['f32_mul(3,4)', fo.f32_mul(3, 4), 12],
  ['i32_max(10,3)', fo.i32_max(10, 3), 10],
  ['i32_max(3,10)', fo.i32_max(3, 10), 10],
  ['i32_max(5,5)', fo.i32_max(5, 5), 5],
  ['f64_convert_i32_s(-1)', fo.f64_convert_i32_s(-1), -1],
  ['i32_trunc_f64_u(3.7)', fo.i32_trunc_f64_u(3.7), 3],
].forEach(([label, actual, expected]) => {
  if (!check(label, actual, expected)) failures++;
});

console.log('');
if (failures === 0) {
  console.log('=== ALL ORACLE CHECKS PASSED ===');
} else {
  console.log(`=== ${failures} ORACLE CHECK(S) FAILED ===`);
  process.exit(1);
}
