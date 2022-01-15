import { range } from 'lodash';
import { Contract } from 'ethers';

import { deploy } from '@koil-finance/helpers/src/contract';
import { toNormalizedWeights } from '@koil-finance/helpers/src/utils/pool-weighted';
import { BigNumberish, bn, fp } from '@koil-finance/helpers/src/numbers';
import { expectEqualWithError } from '@koil-finance/helpers/src/test/relativeError';
import { calculateKPTPrice, calculateSpotPrice } from '@koil-finance/helpers/src/models/pools/weighted/math';

const MAX_RELATIVE_ERROR = 0.00005; // 0.05%, or ~e^0.00005

describe('WeighteOracledMath', function () {
  let mock: Contract;

  before(async function () {
    mock = await deploy('MockWeightedOracleMath');
  });

  function valuesInMagnitude(power: number) {
    return [0.4, 1.2, 2.9, 3.3, 4.8, 5.3, 6.1, 7.4, 8.5, 9.4].map((x) => bn(x * 10 ** power));
  }

  describe('spot price', () => {
    context('with equal weights', () => {
      const weights = toNormalizedWeights([bn(50), bn(50)]);
      itComputesLogSpotPriceWithError(weights);
    });

    context('with different weights', () => {
      const weights = toNormalizedWeights([bn(30), bn(70)]);
      itComputesLogSpotPriceWithError(weights);
    });

    context('with extreme weights', () => {
      const weights = toNormalizedWeights([bn(1), bn(99)]);
      itComputesLogSpotPriceWithError(weights);
    });

    context('with partial weights', () => {
      const weights = toNormalizedWeights([bn(25), bn(50), bn(25)]).slice(0, 2);
      itComputesLogSpotPriceWithError(weights);
    });

    function itComputesLogSpotPriceWithError(normWeights: BigNumberish[]) {
      const minPower = 18;
      const maxPower = 23;

      for (const powerA of range(minPower, maxPower)) {
        const powerB = 20;

        context(`with balances powers of ${powerA} and ${powerB}`, () => {
          it('computes log spot price with bounded relative error', async () => {
            for (const balanceA of valuesInMagnitude(powerA)) {
              for (const balanceB of valuesInMagnitude(powerB)) {
                const actual = await mock.fromLowResLog(
                  await mock.calcLogSpotPrice(normWeights[0], balanceA, normWeights[1], balanceB)
                );

                const expected = calculateSpotPrice([balanceA, balanceB], normWeights);
                expectEqualWithError(actual, expected, MAX_RELATIVE_ERROR);
              }
            }
          });
        });
      }
    }
  });

  describe('KPT price', () => {
    context('with low KPT supply', () => {
      const bptSupply = bn(1e18);
      itComputesLogKPTPriceGivenSupply(bptSupply);
    });

    context('with medium KPT supply', () => {
      const bptSupply = bn(1e25);
      itComputesLogKPTPriceGivenSupply(bptSupply);
    });

    context('with large KPT supply', () => {
      const bptSupply = bn(1e32);
      itComputesLogKPTPriceGivenSupply(bptSupply);
    });

    function itComputesLogKPTPriceGivenSupply(bptSupply: BigNumberish) {
      context('with low weight', () => {
        const weight = fp(0.1);
        itComputesLogKPTPriceWithError(weight);
      });

      context('with medium weight', () => {
        const weight = fp(0.5);
        itComputesLogKPTPriceWithError(weight);
      });

      context('with large weight', () => {
        const weight = fp(0.9);
        itComputesLogKPTPriceWithError(weight);
      });

      function itComputesLogKPTPriceWithError(normWeight: BigNumberish) {
        const minPower = 18;
        const maxPower = 23;

        for (const power of range(minPower, maxPower)) {
          context(`with balances powers of ${power}`, () => {
            it('computes KPT price with bounded relative error', async () => {
              for (const balance of valuesInMagnitude(power)) {
                const logKPTSupply = await mock.toLowResLog(bptSupply);
                const actual = await mock.fromLowResLog(await mock.calcLogKPTPrice(normWeight, balance, logKPTSupply));

                const expected = calculateKPTPrice(balance, normWeight, bptSupply);

                // KPT supply calculation has twice as much error as the others because it sums errors
                expectEqualWithError(actual, expected, MAX_RELATIVE_ERROR * 2);
              }
            });
          });
        }
      }
    }
  });
});
