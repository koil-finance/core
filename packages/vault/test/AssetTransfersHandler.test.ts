import { ethers } from 'hardhat';
import { BigNumber, Contract, ContractReceipt } from 'ethers';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address';

import TokenList, { FUSE_TOKEN_ADDRESS } from '@koil-finance/helpers/src/models/tokens/TokenList';

import { deploy } from '@koil-finance/helpers/src/contract';
import { expectBalanceChange } from '@koil-finance/helpers/src/test/tokenBalance';
import { bn, min } from '@koil-finance/helpers/src/numbers';
import { expect } from 'chai';
import Token from '@koil-finance/helpers/src/models/tokens/Token';
import { forceSendFuse } from './helpers/fuse';

describe('AssetTransfersHandler', function () {
  let handler: Contract;
  let sender: SignerWithAddress, recipient: SignerWithAddress, other: SignerWithAddress;
  let tokens: TokenList;

  before('set up signers', async () => {
    [, sender, recipient, other] = await ethers.getSigners();
  });

  sharedBeforeEach('deploy contracts and mint tokens', async () => {
    tokens = await TokenList.create(['WFUSE', 'DAI', 'MKR']);
    handler = await deploy('MockAssetTransfersHandler', { args: [tokens.WFUSE.address] });

    await tokens.mint({ to: [sender, recipient, handler], amount: bn(100e18) });
    await tokens.approve({ to: handler, from: [sender, recipient] });
  });

  const amount = bn(1e18);
  describe('receiveAsset', () => {
    context('when the asset is FUSE', () => {
      const eth = FUSE_TOKEN_ADDRESS;

      context('with some internal balance', () => {
        sharedBeforeEach('deposit less than amount to internal balance', async () => {
          await handler.depositToInternalBalance(sender.address, tokens.WFUSE.address, amount.div(2));
        });

        context('when not receiving from internal balance', () => {
          itReceivesFuseCorrectly();
        });

        context('when receiving from internal balance', () => {
          const fromInternalBalance = true;

          it('reverts', async () => {
            await expect(
              handler.connect(other).receiveAsset(eth, amount, sender.address, fromInternalBalance, { value: amount })
            ).to.be.revertedWith('INVALID_FUSE_INTERNAL_BALANCE');
          });
        });

        function itReceivesFuseCorrectly() {
          const fromInternalBalance = false;

          it('takes FUSE from the caller', async () => {
            const callerBalanceBefore = await ethers.provider.getBalance(other.address);

            const gasPrice = 10000000;
            const receipt: ContractReceipt = await (
              await handler
                .connect(other)
                .receiveAsset(eth, amount, sender.address, fromInternalBalance, { value: amount, gasPrice })
            ).wait();
            const txFUSE = receipt.gasUsed.mul(gasPrice);

            const callerBalanceAfter = await ethers.provider.getBalance(other.address);

            expect(callerBalanceBefore.sub(callerBalanceAfter)).to.equal(amount.add(txFUSE));
          });

          it('does not keep any FUSE', async () => {
            const balanceBefore = await ethers.provider.getBalance(handler.address);

            await handler.receiveAsset(eth, amount, sender.address, fromInternalBalance, { value: amount });

            const balanceAfter = await ethers.provider.getBalance(handler.address);

            expect(balanceAfter).to.equal(balanceBefore);
          });

          it('wraps received FUSE into WFUSE', async () => {
            await expectBalanceChange(
              () => handler.receiveAsset(eth, amount, sender.address, fromInternalBalance, { value: amount }),
              tokens,
              { account: handler.address, changes: { WFUSE: amount } }
            );
          });

          it('does not return extra FUSE to the caller', async () => {
            const callerBalanceBefore = await ethers.provider.getBalance(other.address);

            const gasPrice = 10000000;
            const receipt: ContractReceipt = await (
              await handler
                .connect(other)
                .receiveAsset(eth, amount, sender.address, fromInternalBalance, { value: amount.mul(2), gasPrice })
            ).wait();
            const txFUSE = receipt.gasUsed.mul(gasPrice);

            const callerBalanceAfter = await ethers.provider.getBalance(other.address);

            const ethSent = txFUSE.add(amount.mul(2));
            expect(callerBalanceBefore.sub(callerBalanceAfter)).to.equal(ethSent);
          });

          it('does not check if any FUSE was supplied', async () => {
            // Regular FUSE transfers are rejected, so we use forceSendFuse to get the handler to hold some FUSE for it to
            // use.
            await forceSendFuse(handler.address, amount);

            // Despite the caller not sending any FUSE, the transaction goes through (using the handler's own balance).
            await expectBalanceChange(
              () => handler.receiveAsset(eth, amount, sender.address, fromInternalBalance, { value: 0 }),
              tokens,
              { account: handler.address, changes: { WFUSE: amount } }
            );
          });

          it('does take WFUSE from internal balance', async () => {
            const preTransferBalance = await handler.getInternalBalance(sender.address, tokens.WFUSE.address);

            await handler.receiveAsset(eth, amount, sender.address, fromInternalBalance, { value: amount });

            const postTransferBalance = await handler.getInternalBalance(sender.address, tokens.WFUSE.address);

            expect(preTransferBalance.sub(postTransferBalance)).to.be.zero;
          });

          it('reverts if not enough FUSE was sent', async () => {
            await expect(
              handler.receiveAsset(eth, amount, sender.address, fromInternalBalance, { value: amount.sub(1) })
            ).to.be.revertedWith('INSUFFICIENT_FUSE');
          });
        }
      });
    });

    context('when the asset is a token', () => {
      context('when the token is WFUSE', () => {
        itReceivesTokenCorrectly('WFUSE');
      });

      context('when the token is not WFUSE', () => {
        itReceivesTokenCorrectly('DAI');
      });

      function itReceivesTokenCorrectly(symbol: string) {
        let token: Token;

        beforeEach(() => {
          token = tokens.findBySymbol(symbol);
        });

        context('when receiving from internal balance', () => {
          context('with no internal balance', () => {
            itReceivesTokenFromInternalBalanceCorrectly();
          });

          context('with some internal balance', () => {
            sharedBeforeEach('deposit less than amount to internal balance', async () => {
              await handler.depositToInternalBalance(sender.address, token.address, amount.div(2));
            });

            itReceivesTokenFromInternalBalanceCorrectly();
          });

          context('with enough internal balance', () => {
            sharedBeforeEach('deposit more than amount to internal balance', async () => {
              await handler.depositToInternalBalance(sender.address, token.address, amount.mul(2));
            });

            itReceivesTokenFromInternalBalanceCorrectly();
          });

          function itReceivesTokenFromInternalBalanceCorrectly() {
            const fromInternalBalance = true;
            let expectedInternalBalanceTransferAmount: BigNumber;

            sharedBeforeEach('compute expected amounts', async () => {
              const currentInternalBalance: BigNumber = await handler.getInternalBalance(sender.address, token.address);

              // When receiving from internal balance, the amount of internal balance to pull is limited by the lower of
              // the current balance and the transfer amount.
              expectedInternalBalanceTransferAmount = min(currentInternalBalance, amount);
            });

            it('deducts the expected amount from internal balance', async () => {
              const preTransferBalance = await handler.getInternalBalance(sender.address, token.address);

              await handler.receiveAsset(token.address, amount, sender.address, fromInternalBalance);

              const postTransferBalance = await handler.getInternalBalance(sender.address, token.address);

              expect(preTransferBalance.sub(postTransferBalance)).to.equal(expectedInternalBalanceTransferAmount);
            });

            it('transfers tokens not taken from internal balance from sender', async () => {
              const expectedTransferAmount = amount.sub(expectedInternalBalanceTransferAmount);

              await expectBalanceChange(
                () => handler.receiveAsset(token.address, amount, sender.address, fromInternalBalance),
                tokens,
                [
                  { account: handler, changes: { [symbol]: expectedTransferAmount } },
                  { account: sender, changes: { [symbol]: expectedTransferAmount.mul(-1) } },
                ]
              );
            });
          }
        });

        context('when not receiving from internal balance', () => {
          context('with no internal balance', () => {
            itReceivesTokensNotFromInternalBalanceCorrectly();
          });

          context('with some internal balance', () => {
            sharedBeforeEach('deposit less than amount to internal balance', async () => {
              await handler.depositToInternalBalance(sender.address, token.address, amount.div(2));
            });

            itReceivesTokensNotFromInternalBalanceCorrectly();
          });

          function itReceivesTokensNotFromInternalBalanceCorrectly() {
            const fromInternalBalance = false;

            it('does not affect sender internal balance', async () => {
              const preTransferBalance = await handler.getInternalBalance(sender.address, token.address);

              await handler.receiveAsset(token.address, amount, sender.address, fromInternalBalance);

              const postTransferBalance = await handler.getInternalBalance(sender.address, token.address);

              expect(postTransferBalance).to.equal(preTransferBalance);
            });

            it('transfers tokens from sender', async () => {
              await expectBalanceChange(
                () => handler.receiveAsset(token.address, amount, sender.address, false),
                tokens,
                [
                  { account: handler, changes: { [symbol]: amount } },
                  { account: sender, changes: { [symbol]: amount.mul(-1) } },
                ]
              );
            });
          }
        });
      }
    });
  });

  describe('sendAsset', () => {
    context('when the asset is FUSE', () => {
      const eth = FUSE_TOKEN_ADDRESS;

      context('when not sending to internal balance', () => {
        itSendsFuseCorrectly();
      });

      context('when sending to internal balance', () => {
        const toInternalBalance = true;

        it('reverts', async () => {
          await expect(handler.sendAsset(eth, amount, recipient.address, toInternalBalance)).to.be.revertedWith(
            'INVALID_FUSE_INTERNAL_BALANCE'
          );
        });
      });

      function itSendsFuseCorrectly() {
        const toInternalBalance = false;

        it('sends FUSE to the recipient', async () => {
          const recipientBalanceBefore = await ethers.provider.getBalance(recipient.address);

          await handler.sendAsset(eth, amount, recipient.address, toInternalBalance);

          const recipientBalanceAfter = await ethers.provider.getBalance(recipient.address);

          expect(recipientBalanceAfter.sub(recipientBalanceBefore)).to.equal(amount);
        });

        it('does not affect the FUSE balance', async () => {
          const recipientBalanceBefore = await ethers.provider.getBalance(recipient.address);

          await handler.sendAsset(eth, amount, recipient.address, toInternalBalance);
          eth;
          const recipientBalanceAfter = await ethers.provider.getBalance(recipient.address);

          expect(recipientBalanceAfter.sub(recipientBalanceBefore)).to.equal(amount);
        });

        it('unwraps WFUSE into FUSE', async () => {
          await expectBalanceChange(
            () => handler.sendAsset(eth, amount, recipient.address, toInternalBalance),
            tokens,
            { account: handler, changes: { WFUSE: amount.mul(-1) } }
          );
        });

        it('does not use internal balance', async () => {
          const recipientInternalBalanceBefore = await handler.getInternalBalance(recipient.address, eth);

          await handler.sendAsset(eth, amount, recipient.address, toInternalBalance);

          const recipientInternalBalanceAfter = await handler.getInternalBalance(recipient.address, eth);

          expect(recipientInternalBalanceAfter).to.equal(recipientInternalBalanceBefore);
        });
      }
    });

    context('when the asset is a token', () => {
      context('when the token is WFUSE', () => {
        itSendsTokensCorrectly('WFUSE');
      });

      context('when the token is not WFUSE', () => {
        itSendsTokensCorrectly('DAI');
      });

      function itSendsTokensCorrectly(symbol: string) {
        let token: Token;

        beforeEach(() => {
          token = tokens.findBySymbol(symbol);
        });

        context('when not sending to internal balance', () => {
          itSendsTokensCorrectlyNotUsingInternalBalance();
        });

        context('when sending to internal balance', () => {
          itSendsTokensCorrectlyUsingInternalBalance();
        });

        function itSendsTokensCorrectlyNotUsingInternalBalance() {
          const toInternalBalance = false;

          it('sends tokens to the recipient', async () => {
            await expectBalanceChange(
              () => handler.sendAsset(token.address, amount, recipient.address, toInternalBalance),
              tokens,
              [
                { account: recipient, changes: { [symbol]: amount } },
                { account: handler, changes: { [symbol]: amount.mul(-1) } },
              ]
            );
          });

          it('does not affect internal balance', async () => {
            const recipientInternalBalanceBefore = await handler.getInternalBalance(recipient.address, token.address);

            await handler.sendAsset(token.address, amount, recipient.address, toInternalBalance);

            const recipientInternalBalanceAfter = await handler.getInternalBalance(recipient.address, token.address);

            expect(recipientInternalBalanceAfter).to.equal(recipientInternalBalanceBefore);
          });
        }

        function itSendsTokensCorrectlyUsingInternalBalance() {
          const toInternalBalance = true;

          it('assigns tokens as internal balance', async () => {
            const recipientInternalBalanceBefore = await handler.getInternalBalance(recipient.address, token.address);

            await handler.sendAsset(token.address, amount, recipient.address, toInternalBalance);

            const recipientInternalBalanceAfter = await handler.getInternalBalance(recipient.address, token.address);

            // Note balance increases by amount, not by amountMinusFees
            expect(recipientInternalBalanceAfter.sub(recipientInternalBalanceBefore)).to.equal(amount);
          });

          it('transfers no tokens', async () => {
            await expectBalanceChange(
              () => handler.sendAsset(token.address, amount, recipient.address, toInternalBalance),
              tokens,
              { account: handler }
            );
          });
        }
      }
    });
  });
});
