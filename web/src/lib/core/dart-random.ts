/**
 * Port bit-per-bit dari `math.Random(seed)` Dart VM (sdk/lib/_internal/vm/lib/math_patch.dart)
 * + `List.shuffle`. Dipakai engine battle & bot agar seed yang sama menghasilkan
 * urutan kartu dan keputusan bot yang sama persis dengan aplikasi Flutter.
 *
 * Diverifikasi terhadap output Dart SDK di `test/dart-random.test.ts`.
 */

const MASK32 = 0xffffffffn;
const MULTIPLIER = 0xffffda61n;
const POW2_32 = 0x100000000;
const POW2_27 = 134217728;
const POW2_53 = 9007199254740992;

const u64 = (value: bigint): bigint => BigInt.asUintN(64, value);

/**
 * Hash-mix seed (Thomas Wang 64-bit). Di Dart VM ini native C++ (`Random_setupSeed`)
 * dengan `uint64_t`, jadi shift-nya logis dan overflow membungkus modulo 2^64.
 */
function setupSeed(seed: number): bigint {
  let n = u64(BigInt(Math.trunc(seed)));
  n = u64(u64(~n) + u64(n << 21n));
  n = u64(n ^ (n >> 24n));
  n = u64(n * 265n);
  n = u64(n ^ (n >> 14n));
  n = u64(n * 21n);
  n = u64(n ^ (n >> 28n));
  n = u64(n + u64(n << 31n));
  if (n === 0n) n = 0x5a17n;
  return n;
}

export class DartRandom {
  private lo: number;
  private hi: number;

  constructor(seed: number) {
    const state = setupSeed(seed);
    this.lo = Number(state & MASK32);
    this.hi = Number((state >> 32n) & MASK32);
    // Dart memutar state 4x agar bit seed tersebar.
    this.nextState();
    this.nextState();
    this.nextState();
    this.nextState();
  }

  private nextState(): void {
    const next = MULTIPLIER * BigInt(this.lo) + BigInt(this.hi);
    this.lo = Number(next & MASK32);
    this.hi = Number((next >> 32n) & MASK32);
  }

  /** Bilangan bulat seragam di [0, max). `max` harus 1..2^32. */
  nextInt(max: number): number {
    if (!Number.isInteger(max) || max <= 0 || max > POW2_32) {
      throw new RangeError(`max harus 1..2^32, didapat ${max}`);
    }
    if (Number.isInteger(Math.log2(max))) {
      // Jalur cepat pangkat dua (Dart: `(max & -max) == max`).
      this.nextState();
      return (this.lo & (max - 1)) >>> 0;
    }
    let rnd32: number;
    let result: number;
    do {
      this.nextState();
      rnd32 = this.lo;
      result = rnd32 % max;
    } while (rnd32 - result + max > POW2_32);
    return result;
  }

  nextDouble(): number {
    return (this.nextInt(1 << 26) * POW2_27 + this.nextInt(1 << 27)) / POW2_53;
  }

  nextBool(): boolean {
    return this.nextInt(2) === 0;
  }
}

/** `List.shuffle(random)` Dart — mengacak in-place, sama urutan pemanggilan RNG-nya. */
export function dartShuffle<T>(items: T[], random: DartRandom): T[] {
  let length = items.length;
  while (length > 1) {
    const pos = random.nextInt(length);
    length -= 1;
    const tmp = items[length] as T;
    items[length] = items[pos] as T;
    items[pos] = tmp;
  }
  return items;
}

/** `double.round()` Dart: setengah dibulatkan menjauhi nol (beda dengan Math.round untuk negatif). */
export function dartRound(value: number): number {
  return value < 0 ? -Math.round(-value) : Math.round(value);
}
