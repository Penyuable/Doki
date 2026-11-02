import { describe, expect, it } from 'vitest';
import {
  fallbackRarity,
  rollRarity,
  tenPullUpgrade,
  uniformPick,
  weightedPick,
} from '../src/modules/gacha/gacha.math.js';
import { GACHA_RATES, RARITIES, type Rarity } from '../src/config/economy.js';

const stub = (value: number) => () => value;

function mulberry32(seed: number) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const weighted = GACHA_RATES.map((r) => ({ value: r.rarity, weight: r.weight }));

describe('weightedPick — batas bucket', () => {
  const cases: Array<[number, Rarity]> = [
    [0, 'Common'],
    [0.5999, 'Common'],
    [0.6, 'Uncommon'],
    [0.8499, 'Uncommon'],
    [0.85, 'Rare'],
    [0.9499, 'Rare'],
    [0.95, 'Epic'],
    [0.9899, 'Epic'],
    [0.99, 'Legendary'],
    [0.9989, 'Legendary'],
    [0.999, 'Master'],
    [0.9999, 'Master'],
  ];

  it.each(cases)('rng %f → %s', (value, expected) => {
    expect(weightedPick(weighted, stub(value))).toBe(expected);
  });

  it('rng negatif tidak crash', () => {
    expect(() => weightedPick(weighted, stub(-1))).not.toThrow();
  });

  it('total weight 0 ditolak', () => {
    expect(() => weightedPick([{ value: 'x', weight: 0 }], stub(0.5))).toThrow();
  });
});

describe('rollRarity — pity', () => {
  it('counter 47 → roll normal', () => {
    const r = rollRarity(47, stub(0.1));
    expect(r.wasPity).toBe(false);
    expect(r.rarity).toBe('Common');
  });

  it('counter 48 → roll normal', () => {
    expect(rollRarity(48, stub(0.5)).wasPity).toBe(false);
  });

  it('counter 49 → dipaksa Epic+ dan wasPity', () => {
    const r = rollRarity(49, stub(0.5));
    expect(r.wasPity).toBe(true);
    expect(['Epic', 'Legendary', 'Master']).toContain(r.rarity);
  });

  it('bonus pity: 80% Epic / 18% Legendary / 2% Master', () => {
    expect(rollRarity(49, stub(0.0)).rarity).toBe('Epic');
    expect(rollRarity(49, stub(0.81)).rarity).toBe('Legendary');
    expect(rollRarity(49, stub(0.99)).rarity).toBe('Master');
  });
});

describe('10x guarantee', () => {
  it('semua common → hasil terakhir jadi Rare', () => {
    const commons = Array.from({ length: 10 }, () => 'Common' as Rarity);
    const up = tenPullUpgrade(commons, false, stub(0.5));
    expect(up.guaranteed).toBe(true);
    expect(up.rarity).toBe('Rare');
  });

  it('sudah ada Rare+ → tidak diubah', () => {
    const list = Array.from({ length: 9 }, () => 'Common' as Rarity);
    list.push('Epic');
    const up = tenPullUpgrade(list, false, stub(0.5));
    expect(up.guaranteed).toBe(false);
    expect(up.rarity).toBe('Epic');
  });

  it('pity aktif pada pull terakhir → bonus Epic+', () => {
    const commons = Array.from({ length: 10 }, () => 'Common' as Rarity);
    const up = tenPullUpgrade(commons, true, stub(0.0));
    expect(up.guaranteed).toBe(true);
    expect(up.rarity).toBe('Epic');
  });
});

describe('uniformPick & fallback', () => {
  it('mengambil indeks terakhir untuk rng mendekati 1', () => {
    expect(uniformPick(['a', 'b', 'c'], stub(0.999))).toBe('c');
  });

  it('fallback turun ke rarity tersedia', () => {
    expect(fallbackRarity('Epic', new Set(['Common', 'Rare']))).toBe('Rare');
    expect(fallbackRarity('Epic', new Set(['Common']))).toBe('Common');
  });
});

describe('distribusi 100.000 pull (chi-square, alpha 0.01)', () => {
  it('sesuai tabel rate', () => {
    const rng = mulberry32(20261101);
    const counts = new Map<Rarity, number>();
    for (const r of RARITIES) counts.set(r, 0);

    const N = 100_000;
    for (let i = 0; i < N; i += 1) {
      const rarity = rollRarity(0, rng).rarity;
      counts.set(rarity, (counts.get(rarity) ?? 0) + 1);
    }

    const expected = new Map<Rarity, number>(
      GACHA_RATES.map((r) => [r.rarity, (r.weight / 10_000) * N]),
    );

    let chi2 = 0;
    for (const rarity of RARITIES) {
      const e = expected.get(rarity) ?? 0;
      const o = counts.get(rarity) ?? 0;
      chi2 += ((o - e) ** 2) / e;
    }

    // df = 5, critical value alpha 0.01 = 15.086
    expect(chi2).toBeLessThan(15.086);

    for (const [rarity, e] of expected) {
      const o = counts.get(rarity) ?? 0;
      expect(Math.abs(o - e) / N).toBeLessThan(0.006);
    }
  });
});
