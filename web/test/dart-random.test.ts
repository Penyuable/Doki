import { test } from 'node:test';
import assert from 'node:assert/strict';
import { DartRandom, dartRound, dartShuffle } from '../src/lib/core/dart-random.ts';

// Output referensi dari Dart SDK 3.13 (`dart run`):
//   r.nextInt(100) x5, nextInt(7), nextInt(1<<20), nextBool, nextDouble,
//   [0..9].shuffle(r), nextInt(2147483646)
const GOLDEN: Array<[number, string]> = [
  [1, '4 87 95 59 75 6 954312 false 0.436434278390274 0-6-9-1-7-3-2-8-5-4 1642353199'],
  [42, '87 58 4 85 77 3 150415 false 0.790440332152335 8-6-2-7-1-5-4-3-0-9 196468142'],
  [123456789, '83 58 66 89 53 6 1014537 true 0.459522134234661 0-6-3-7-4-5-1-2-8-9 343931977'],
  [2147483646, '43 16 77 59 5 0 767007 true 0.947900521306059 6-2-1-9-5-0-8-3-4-7 341446121'],
  [2654435731, '79 91 37 49 59 1 302180 false 0.518928915549340 5-7-8-2-1-3-0-4-6-9 600207357'],
];

test('DartRandom identik dengan math.Random Dart untuk seed yang sama', () => {
  for (const [seed, expected] of GOLDEN) {
    const r = new DartRandom(seed);
    const out: string[] = [];
    for (let i = 0; i < 5; i += 1) out.push(String(r.nextInt(100)));
    out.push(String(r.nextInt(7)));
    out.push(String(r.nextInt(1 << 20)));
    out.push(String(r.nextBool()));
    out.push(r.nextDouble().toFixed(15));
    out.push(dartShuffle([0, 1, 2, 3, 4, 5, 6, 7, 8, 9], r).join('-'));
    out.push(String(r.nextInt(2147483646)));
    assert.equal(out.join(' '), expected, `seed ${seed}`);
  }
});

test('nextInt menolak batas di luar 1..2^32', () => {
  const r = new DartRandom(7);
  assert.throws(() => r.nextInt(0), RangeError);
  assert.throws(() => r.nextInt(2 ** 32 + 1), RangeError);
});

test('dartRound membulatkan setengah menjauhi nol', () => {
  assert.equal(dartRound(2.5), 3);
  assert.equal(dartRound(-2.5), -3);
  assert.equal(dartRound(-0.4), -0);
  assert.equal(dartRound(1.49), 1);
});
