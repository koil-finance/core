import { expect } from 'chai';
import { Contract } from 'ethers';

import { deploy } from '@koil-finance/helpers/src/contract';

describe('KoilErrors', function () {
  let errors: Contract;

  beforeEach('deploy errors', async () => {
    errors = await deploy('KoilErrorsMock');
  });

  it('encodes the error code as expected', async () => {
    await expect(errors.fail(123)).to.be.revertedWith('123');
  });

  it('translates the error code to its corresponding string if existent', async () => {
    await expect(errors.fail(102)).to.be.revertedWith('UNSORTED_TOKENS');
  });
});
