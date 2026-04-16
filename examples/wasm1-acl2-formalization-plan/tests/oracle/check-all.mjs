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

console.log('');
if (failures === 0) {
  console.log('=== ALL ORACLE CHECKS PASSED ===');
} else {
  console.log(`=== ${failures} ORACLE CHECK(S) FAILED ===`);
  process.exit(1);
}
