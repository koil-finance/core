import { expect } from 'chai';
import { fp } from '@koil-finance/helpers/src/numbers';

import TokenList from '@koil-finance/helpers/src/models/tokens/TokenList';
import WeightedPool from '@koil-finance/helpers/src/models/pools/weighted/WeightedPool';

import { itBehavesAsWeightedPool } from './BaseWeightedPool.behavior';

describe('BaseWeightedPool', function () {
  context('for a 1 token pool', () => {
    it('reverts if there is a single token', async () => {
      const tokens = await TokenList.create(1);
      const weights = [fp(1)];

      await expect(WeightedPool.create({ tokens, weights })).to.be.revertedWith('MIN_TOKENS');
    });
  });

  context('for a 2 token pool', () => {
    itBehavesAsWeightedPool(2);
  });

  context('for a 3 token pool', () => {
    itBehavesAsWeightedPool(3);
  });

  context('for a too-many token pool', () => {
    it('reverts if there are too many tokens', async () => {
      // The maximum number of tokens is 20
      const tokens = await TokenList.create(21);
      const weights = new Array(21).fill(fp(1));

      await expect(WeightedPool.create({ tokens, weights })).to.be.revertedWith('MAX_TOKENS');
    });
  });
});
