/**
 * Golden lintas platform: pertandingan bot-vs-bot penuh harus menghasilkan
 * logHash yang SAMA dengan engine Dart di aplikasi Flutter.
 * Referensi dihasilkan dari frontend/lib (BattleEngine + BotAI Dart, SDK 3.13).
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { battleEngine } from '../src/lib/battle/engine.ts';
import { BotAI, botSeedFor } from '../src/lib/battle/bot-ai.ts';
import { END_TURN, IllegalActionError, type BattleState } from '../src/lib/battle/models.ts';
import { DIFFICULTIES } from '../src/lib/config/game-config.ts';
import { goldenBotDeck, starterDeck } from './support/fixtures.ts';

const DART_GOLDEN = `
1 easy win t21 n97 log195 6420aac3076c21ce5909dcfa5b22f62953ef0af3758f785dfc4fd5c5ffec14c0
1 medium loss t18 n124 log245 660701814cc95f94f02b5a0d28f0df8606635c85fd3843c2e0beaf6b3af41faf
1 master loss t13 n103 log201 67be09247544238a5b7880be618c4c0afdbd6f486a594b825e374846184a8c07
42 easy loss t21 n99 log203 c6d754a6ca49ae240201200ea4b12ba824af9f43bd78d88d85c104054703a2ac
42 medium loss t19 n135 log253 5c5386949d12b8a1be342f42ff27f458270cc3059529a50e94f94f8ae408d431
42 master loss t13 n118 log226 238a8536ed417857718cc21e5f22641915f2155cfe2ce92ecd9757efddd2ec27
777 easy loss t21 n113 log222 05715f1e5b9eeedf8c27ddc4c5c9d966e36e3e77d2954000bc79c905e58344b9
777 medium loss t21 n146 log299 7c7ddf365674da25bf27dcb8b0070a2b953ec0eda0ac2570bacc4106957f3a52
777 master loss t21 n159 log336 6746def6259865eb19c63606873ca0b692d68f6168ef9af44ae9118bd412d5a7
123456 easy loss t21 n108 log213 05912f2b223cc5859b0b2b59fb12501855681818e05239b86d1b21426754debd
123456 medium loss t21 n153 log290 7cd765ddf2ad957377322ed118b6b25dd0f63fd04fc5f7e0101436387fcce9d4
123456 master loss t18 n137 log266 de5502d2010cc0776a7bb1f87ea343ab9fa9a33ae8904bc0fdba18dcfa512c18
2000000000 easy win t21 n125 log246 f8cbadab820c4fd1c8dab7f71c5463dc5c75b68e13632a62372a0c35d7c0ad53
2000000000 medium loss t17 n125 log250 2a6c3f7e0cc214b65e96cb04a0b93529e71ed2849b4ba64c57dc35669a24c235
2000000000 master loss t13 n113 log218 a5c6924268cacc8b358d4c96f59be50845c23864ff7f19dd2e56eb1aa19a04b7
`
  .trim()
  .split('\n');

test('engine + bot web identik dengan Dart (golden logHash, 15 pertandingan)', () => {
  const player = starterDeck();
  const bot = goldenBotDeck();
  const actual: string[] = [];

  for (const seed of [1, 42, 777, 123456, 2000000000]) {
    for (const difficulty of DIFFICULTIES) {
      let state: BattleState = battleEngine.start({ playerDeck: player, botDeck: bot, seed });
      const playerBot = new BotAI({ difficulty, seed: seed + 11 });
      const enemyBot = new BotAI({ difficulty, seed: botSeedFor(seed) });
      let n = 0;
      while (!state.isTerminal && n < 3000) {
        const side = state.activeSide;
        const action = (side === 'player' ? playerBot : enemyBot).decide(state, side);
        try {
          state = battleEngine.apply(state, action);
        } catch (error) {
          if (!(error instanceof IllegalActionError)) throw error;
          state = battleEngine.apply(state, END_TURN);
        }
        n += 1;
      }
      actual.push(`${seed} ${difficulty} ${state.outcome} t${state.turnNumber} n${n} log${state.log.length} ${state.logHash()}`);
    }
  }

  assert.deepEqual(actual, DART_GOLDEN);
});
