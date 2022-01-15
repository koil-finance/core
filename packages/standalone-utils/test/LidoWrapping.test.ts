import { expect } from 'chai';
import { ethers } from 'hardhat';
import { BigNumber, Contract, ContractReceipt } from 'ethers';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import Token from '@koil-finance/helpers/src/models/tokens/Token';
import TokenList from '@koil-finance/helpers/src/models/tokens/TokenList';
import StablePool from '@koil-finance/helpers/src/models/pools/stable/StablePool';

import { SwapKind } from '@koil-finance/helpers/src/types';
import { WeightedPoolEncoder } from '@koil-finance/helpers/src/utils/pool-weighted';
import * as expectEvent from '@koil-finance/helpers/src/test/expectEvent';
import { deploy, deployedAt } from '@koil-finance/helpers/src/contract';
import { actionId } from '@koil-finance/helpers/src/models/misc/actions';
import { MAX_INT256, MAX_UINT256, ZERO_ADDRESS } from '@koil-finance/helpers/src/constants';
import { BigNumberish, bn, fp } from '@koil-finance/helpers/src/numbers';
import Vault from '@koil-finance/helpers/src/models/vault/Vault';
import { Account } from '@koil-finance/helpers/src/models/types/types';
import TypesConverter from '@koil-finance/helpers/src/models/types/TypesConverter';
import { Dictionary } from 'lodash';

describe('LidoWrapping', function () {
  let stFUSE: Token, wstFUSE: Token;
  let senderUser: SignerWithAddress, recipientUser: SignerWithAddress, admin: SignerWithAddress;
  let vault: Vault;
  let relayer: Contract, relayerLibrary: Contract;

  before('setup signer', async () => {
    [, admin, senderUser, recipientUser] = await ethers.getSigners();
  });

  sharedBeforeEach('deploy Vault', async () => {
    const [deployer] = await ethers.getSigners();
    vault = await Vault.create({ admin });

    const stFUSEContract = await deploy('MockStFUSE', { args: [deployer.address, 'stFUSE', 'stFUSE', 18] });
    stFUSE = new Token('stFUSE', 'stFUSE', 18, stFUSEContract);

    const wstFUSEContract = await deploy('MockWstFUSE', { args: [stFUSE.address] });
    wstFUSE = new Token('wstFUSE', 'wstFUSE', 18, wstFUSEContract);
  });

  sharedBeforeEach('mint tokens to senderUser', async () => {
    await stFUSE.mint(senderUser, fp(100));
    await stFUSE.approve(vault.address, fp(100), { from: senderUser });

    await stFUSE.mint(senderUser, fp(2500));
    await stFUSE.approve(wstFUSE.address, fp(150), { from: senderUser });
    await wstFUSE.instance.connect(senderUser).wrap(fp(150));
  });

  sharedBeforeEach('set up relayer', async () => {
    // Deploy Relayer
    relayerLibrary = await deploy('MockBatchRelayerLibrary', { args: [vault.address, wstFUSE.address] });
    relayer = await deployedAt('KoilRelayer', await relayerLibrary.getEntrypoint());

    // Authorize Relayer for all actions
    const relayerActionIds = await Promise.all(
      ['swap', 'batchSwap', 'joinPool', 'exitPool', 'setRelayerApproval', 'manageUserBalance'].map((action) =>
        actionId(vault.instance, action)
      )
    );
    const authorizer = await deployedAt('vault/Authorizer', await vault.instance.getAuthorizer());
    await authorizer.connect(admin).grantRolesGlobally(relayerActionIds, relayer.address);

    // Approve relayer by sender
    await vault.instance.connect(senderUser).setRelayerApproval(senderUser.address, relayer.address, true);
  });

  const CHAINED_REFERENCE_PREFIX = 'ba10';
  function toChainedReference(key: BigNumberish): BigNumber {
    // The full padded prefix is 66 characters long, with 64 hex characters and the 0x prefix.
    const paddedPrefix = `0x${CHAINED_REFERENCE_PREFIX}${'0'.repeat(64 - CHAINED_REFERENCE_PREFIX.length)}`;

    return BigNumber.from(paddedPrefix).add(key);
  }

  function encodeApprove(token: Token, amount: BigNumberish): string {
    return relayerLibrary.interface.encodeFunctionData('approveVault', [token.address, amount]);
  }

  function encodeWrap(
    sender: Account,
    recipient: Account,
    amount: BigNumberish,
    outputReference?: BigNumberish
  ): string {
    return relayerLibrary.interface.encodeFunctionData('wrapStFUSE', [
      TypesConverter.toAddress(sender),
      TypesConverter.toAddress(recipient),
      amount,
      outputReference ?? 0,
    ]);
  }

  function encodeUnwrap(
    sender: Account,
    recipient: Account,
    amount: BigNumberish,
    outputReference?: BigNumberish
  ): string {
    return relayerLibrary.interface.encodeFunctionData('unwrapWstFUSE', [
      TypesConverter.toAddress(sender),
      TypesConverter.toAddress(recipient),
      amount,
      outputReference ?? 0,
    ]);
  }

  function encodeStakeFUSE(recipient: Account, amount: BigNumberish, outputReference?: BigNumberish): string {
    return relayerLibrary.interface.encodeFunctionData('stakeFUSE', [
      TypesConverter.toAddress(recipient),
      amount,
      outputReference ?? 0,
    ]);
  }

  function encodeStakeFUSEAndWrap(recipient: Account, amount: BigNumberish, outputReference?: BigNumberish): string {
    return relayerLibrary.interface.encodeFunctionData('stakeFUSEAndWrap', [
      TypesConverter.toAddress(recipient),
      amount,
      outputReference ?? 0,
    ]);
  }

  async function setChainedReferenceContents(ref: BigNumberish, value: BigNumberish): Promise<void> {
    await relayer.multicall([relayerLibrary.interface.encodeFunctionData('setChainedReferenceValue', [ref, value])]);
  }

  async function expectChainedReferenceContents(ref: BigNumberish, expectedValue: BigNumberish): Promise<void> {
    const receipt = await (
      await relayer.multicall([relayerLibrary.interface.encodeFunctionData('getChainedReferenceValue', [ref])])
    ).wait();

    expectEvent.inIndirectReceipt(receipt, relayerLibrary.interface, 'ChainedReferenceValueRead', {
      value: bn(expectedValue),
    });
  }

  function expectTransferEvent(
    receipt: ContractReceipt,
    args: { from?: string; to?: string; value?: BigNumberish },
    token: Token
  ) {
    return expectEvent.inIndirectReceipt(receipt, token.instance.interface, 'Transfer', args, token.address);
  }

  describe('primitives', () => {
    const amount = fp(1);

    describe('wrapStFUSE', () => {
      let tokenSender: Account, tokenRecipient: Account;

      context('sender = senderUser, recipient = relayer', () => {
        beforeEach(() => {
          tokenSender = senderUser;
          tokenRecipient = relayer;
        });
        testWrap();
      });

      context('sender = senderUser, recipient = senderUser', () => {
        beforeEach(() => {
          tokenSender = senderUser;
          tokenRecipient = senderUser;
        });
        testWrap();
      });

      context('sender = relayer, recipient = relayer', () => {
        beforeEach(async () => {
          await stFUSE.transfer(relayer, amount, { from: senderUser });
          tokenSender = relayer;
          tokenRecipient = relayer;
        });
        testWrap();
      });

      context('sender = relayer, recipient = senderUser', () => {
        beforeEach(async () => {
          await stFUSE.transfer(relayer, amount, { from: senderUser });
          tokenSender = relayer;
          tokenRecipient = senderUser;
        });
        testWrap();
      });

      function testWrap(): void {
        it('wraps with immediate amounts', async () => {
          const expectedWstFUSEAmount = await wstFUSE.instance.getWstFUSEByStFUSE(amount);

          const receipt = await (
            await relayer.connect(senderUser).multicall([encodeWrap(tokenSender, tokenRecipient, amount)])
          ).wait();

          const relayerIsSender = TypesConverter.toAddress(tokenSender) === relayer.address;
          expectTransferEvent(
            receipt,
            {
              from: TypesConverter.toAddress(tokenSender),
              to: TypesConverter.toAddress(relayerIsSender ? wstFUSE : relayer),
              value: amount,
            },
            stFUSE
          );
          const relayerIsRecipient = TypesConverter.toAddress(tokenRecipient) === relayer.address;
          expectTransferEvent(
            receipt,
            {
              from: TypesConverter.toAddress(relayerIsRecipient ? ZERO_ADDRESS : relayer),
              to: TypesConverter.toAddress(relayerIsRecipient ? relayer : tokenRecipient),
              value: expectedWstFUSEAmount,
            },
            wstFUSE
          );
        });

        it('stores wrap output as chained reference', async () => {
          const expectedWstFUSEAmount = await wstFUSE.instance.getWstFUSEByStFUSE(amount);

          await relayer
            .connect(senderUser)
            .multicall([encodeWrap(tokenSender, tokenRecipient, amount, toChainedReference(0))]);

          await expectChainedReferenceContents(toChainedReference(0), expectedWstFUSEAmount);
        });

        it('wraps with chained references', async () => {
          const expectedWstFUSEAmount = await wstFUSE.instance.getWstFUSEByStFUSE(amount);
          await setChainedReferenceContents(toChainedReference(0), amount);

          const receipt = await (
            await relayer
              .connect(senderUser)
              .multicall([encodeWrap(tokenSender, tokenRecipient, toChainedReference(0))])
          ).wait();

          const relayerIsSender = TypesConverter.toAddress(tokenSender) === relayer.address;
          expectTransferEvent(
            receipt,
            {
              from: TypesConverter.toAddress(tokenSender),
              to: TypesConverter.toAddress(relayerIsSender ? wstFUSE : relayer),
              value: amount,
            },
            stFUSE
          );
          const relayerIsRecipient = TypesConverter.toAddress(tokenRecipient) === relayer.address;
          expectTransferEvent(
            receipt,
            {
              from: TypesConverter.toAddress(relayerIsRecipient ? ZERO_ADDRESS : relayer),
              to: TypesConverter.toAddress(relayerIsRecipient ? relayer : tokenRecipient),
              value: expectedWstFUSEAmount,
            },
            wstFUSE
          );
        });
      }
    });

    describe('unwrapWstFUSE', () => {
      let tokenSender: Account, tokenRecipient: Account;

      context('sender = senderUser, recipient = relayer', () => {
        beforeEach(async () => {
          await wstFUSE.approve(vault.address, fp(10), { from: senderUser });
          tokenSender = senderUser;
          tokenRecipient = relayer;
        });
        testUnwrap();
      });

      context('sender = senderUser, recipient = senderUser', () => {
        beforeEach(async () => {
          await wstFUSE.approve(vault.address, fp(10), { from: senderUser });
          tokenSender = senderUser;
          tokenRecipient = senderUser;
        });
        testUnwrap();
      });

      context('sender = relayer, recipient = relayer', () => {
        beforeEach(async () => {
          await wstFUSE.transfer(relayer, amount, { from: senderUser });
          tokenSender = relayer;
          tokenRecipient = relayer;
        });
        testUnwrap();
      });

      context('sender = relayer, recipient = senderUser', () => {
        beforeEach(async () => {
          await wstFUSE.transfer(relayer, amount, { from: senderUser });
          tokenSender = relayer;
          tokenRecipient = senderUser;
        });
        testUnwrap();
      });

      function testUnwrap(): void {
        it('unwraps with immediate amounts', async () => {
          const receipt = await (
            await relayer.connect(senderUser).multicall([encodeUnwrap(tokenSender, tokenRecipient, amount)])
          ).wait();

          const relayerIsSender = TypesConverter.toAddress(tokenSender) === relayer.address;
          expectTransferEvent(
            receipt,
            {
              from: TypesConverter.toAddress(tokenSender),
              to: TypesConverter.toAddress(relayerIsSender ? ZERO_ADDRESS : relayer),
              value: amount,
            },
            wstFUSE
          );
          const relayerIsRecipient = TypesConverter.toAddress(tokenRecipient) === relayer.address;
          expectTransferEvent(
            receipt,
            {
              from: TypesConverter.toAddress(relayerIsRecipient ? wstFUSE : relayer),
              to: TypesConverter.toAddress(relayerIsRecipient ? relayer : tokenRecipient),
              value: await wstFUSE.instance.getStFUSEByWstFUSE(amount),
            },
            stFUSE
          );
        });

        it('stores unwrap output as chained reference', async () => {
          await relayer
            .connect(senderUser)
            .multicall([encodeUnwrap(tokenSender, tokenRecipient, amount, toChainedReference(0))]);

          const stFUSEAmount = await wstFUSE.instance.getStFUSEByWstFUSE(amount);
          await expectChainedReferenceContents(toChainedReference(0), stFUSEAmount);
        });

        it('unwraps with chained references', async () => {
          await setChainedReferenceContents(toChainedReference(0), amount);

          const receipt = await (
            await relayer
              .connect(senderUser)
              .multicall([encodeUnwrap(tokenSender, tokenRecipient, toChainedReference(0))])
          ).wait();

          const relayerIsSender = TypesConverter.toAddress(tokenSender) === relayer.address;
          expectTransferEvent(
            receipt,
            {
              from: TypesConverter.toAddress(tokenSender),
              to: TypesConverter.toAddress(relayerIsSender ? ZERO_ADDRESS : relayer),
              value: amount,
            },
            wstFUSE
          );
          const relayerIsRecipient = TypesConverter.toAddress(tokenRecipient) === relayer.address;
          expectTransferEvent(
            receipt,
            {
              from: TypesConverter.toAddress(relayerIsRecipient ? wstFUSE : relayer),
              to: TypesConverter.toAddress(relayerIsRecipient ? relayer : tokenRecipient),
              value: await wstFUSE.instance.getStFUSEByWstFUSE(amount),
            },
            stFUSE
          );
        });
      }
    });

    describe('stakeFUSE', () => {
      let tokenRecipient: Account;

      context('recipient = senderUser', () => {
        beforeEach(() => {
          tokenRecipient = senderUser;
        });
        testStake();
      });

      context('recipient = relayer', () => {
        beforeEach(() => {
          tokenRecipient = relayer;
        });
        testStake();
      });

      function testStake(): void {
        it('stakes with immediate amounts', async () => {
          const receipt = await (
            await relayer.connect(senderUser).multicall([encodeStakeFUSE(tokenRecipient, amount)], { value: amount })
          ).wait();

          const relayerIsRecipient = TypesConverter.toAddress(tokenRecipient) === relayer.address;
          expectTransferEvent(
            receipt,
            {
              from: relayerIsRecipient ? ZERO_ADDRESS : relayer.address,
              to: relayerIsRecipient ? relayer.address : TypesConverter.toAddress(tokenRecipient),
              value: amount,
            },
            stFUSE
          );
        });

        it('returns excess FUSE', async () => {
          const excess = fp(1.5);
          const senderBalanceBefore = await ethers.provider.getBalance(senderUser.address);

          const tx = await relayer
            .connect(senderUser)
            .multicall([encodeStakeFUSE(tokenRecipient, amount)], { value: amount.add(excess) });
          const receipt = await tx.wait();

          expectTransferEvent(receipt, { value: amount }, stFUSE);

          const txCost = tx.gasPrice.mul(receipt.gasUsed);
          expect(await ethers.provider.getBalance(senderUser.address)).to.equal(
            senderBalanceBefore.sub(txCost).sub(amount)
          );
        });

        it('stores stake output as chained reference', async () => {
          await relayer
            .connect(senderUser)
            .multicall([encodeStakeFUSE(tokenRecipient, amount, toChainedReference(0))], { value: amount });

          await expectChainedReferenceContents(toChainedReference(0), amount);
        });

        it('stakes with chained references', async () => {
          await setChainedReferenceContents(toChainedReference(0), amount);

          const receipt = await (
            await relayer
              .connect(senderUser)
              .multicall([encodeStakeFUSE(tokenRecipient, toChainedReference(0))], { value: amount })
          ).wait();

          expectEvent.inIndirectReceipt(receipt, stFUSE.instance.interface, 'FuseStaked', { amount });

          const relayerIsRecipient = TypesConverter.toAddress(tokenRecipient) === relayer.address;
          expectTransferEvent(
            receipt,
            {
              from: TypesConverter.toAddress(relayerIsRecipient ? ZERO_ADDRESS : relayer),
              to: TypesConverter.toAddress(relayerIsRecipient ? relayer : tokenRecipient),
              value: amount,
            },
            stFUSE
          );
        });
      }
    });

    describe('stakeFUSEAndWrap', () => {
      let tokenRecipient: Account;

      context('recipient = senderUser', () => {
        beforeEach(() => {
          tokenRecipient = senderUser;
        });
        testStakeAndWrap();
      });

      context('recipient = relayer', () => {
        beforeEach(() => {
          tokenRecipient = relayer;
        });
        testStakeAndWrap();
      });

      function testStakeAndWrap(): void {
        it('stakes with immediate amounts', async () => {
          const expectedWstFUSEAmount = await wstFUSE.instance.getWstFUSEByStFUSE(amount);

          const receipt = await (
            await relayer
              .connect(senderUser)
              .multicall([encodeStakeFUSEAndWrap(tokenRecipient, amount)], { value: amount })
          ).wait();

          const relayerIsRecipient = TypesConverter.toAddress(tokenRecipient) === relayer.address;
          expectTransferEvent(
            receipt,
            {
              from: TypesConverter.toAddress(relayerIsRecipient ? ZERO_ADDRESS : relayer),
              to: TypesConverter.toAddress(relayerIsRecipient ? relayer : tokenRecipient),
              value: expectedWstFUSEAmount,
            },
            wstFUSE
          );
        });

        it('stores stake output as chained reference', async () => {
          const expectedWstFUSEAmount = await wstFUSE.instance.getWstFUSEByStFUSE(amount);

          await relayer
            .connect(senderUser)
            .multicall([encodeStakeFUSEAndWrap(tokenRecipient, amount, toChainedReference(0))], { value: amount });

          await expectChainedReferenceContents(toChainedReference(0), expectedWstFUSEAmount);
        });

        it('stakes with chained references', async () => {
          const expectedWstFUSEAmount = await wstFUSE.instance.getWstFUSEByStFUSE(amount);

          await setChainedReferenceContents(toChainedReference(0), amount);

          const receipt = await (
            await relayer
              .connect(senderUser)
              .multicall([encodeStakeFUSEAndWrap(tokenRecipient, toChainedReference(0))], { value: amount })
          ).wait();

          expectEvent.inIndirectReceipt(receipt, stFUSE.instance.interface, 'FuseStaked', { amount });

          const relayerIsRecipient = TypesConverter.toAddress(tokenRecipient) === relayer.address;
          expectTransferEvent(
            receipt,
            {
              from: TypesConverter.toAddress(relayerIsRecipient ? ZERO_ADDRESS : relayer),
              to: TypesConverter.toAddress(relayerIsRecipient ? relayer : tokenRecipient),
              value: expectedWstFUSEAmount,
            },
            wstFUSE
          );
        });
      }
    });
  });

  describe('complex actions', () => {
    let WFUSE: Token;
    let poolTokens: TokenList;
    let poolId: string;
    let pool: StablePool;

    sharedBeforeEach('deploy pool', async () => {
      WFUSE = await Token.deployedAt(await vault.instance.WFUSE());
      poolTokens = new TokenList([WFUSE, wstFUSE]).sort();

      pool = await StablePool.create({ tokens: poolTokens, vault });
      poolId = pool.poolId;

      await WFUSE.mint(senderUser, fp(2));
      await WFUSE.approve(vault, MAX_UINT256, { from: senderUser });

      // Seed liquidity in pool
      await WFUSE.mint(admin, fp(200));
      await WFUSE.approve(vault, MAX_UINT256, { from: admin });

      await stFUSE.mint(admin, fp(150));
      await stFUSE.approve(wstFUSE, fp(150), { from: admin });
      await wstFUSE.instance.connect(admin).wrap(fp(150));
      await wstFUSE.approve(vault, MAX_UINT256, { from: admin });

      await pool.init({ initialBalances: fp(100), from: admin });
    });

    describe('swap', () => {
      function encodeSwap(params: {
        poolId: string;
        kind: SwapKind;
        tokenIn: Token;
        tokenOut: Token;
        amount: BigNumberish;
        sender: Account;
        recipient: Account;
        outputReference?: BigNumberish;
      }): string {
        return relayerLibrary.interface.encodeFunctionData('swap', [
          {
            poolId: params.poolId,
            kind: params.kind,
            assetIn: params.tokenIn.address,
            assetOut: params.tokenOut.address,
            amount: params.amount,
            userData: '0x',
          },
          {
            sender: TypesConverter.toAddress(params.sender),
            recipient: TypesConverter.toAddress(params.recipient),
            fromInternalBalance: false,
            toInternalBalance: false,
          },
          0,
          MAX_UINT256,
          0,
          params.outputReference ?? 0,
        ]);
      }

      describe('swap using stFUSE as an input', () => {
        let receipt: ContractReceipt;
        const amount = fp(1);

        sharedBeforeEach('swap stFUSE for WFUSE', async () => {
          receipt = await (
            await relayer.connect(senderUser).multicall([
              encodeWrap(senderUser.address, relayer.address, amount, toChainedReference(0)),
              encodeApprove(wstFUSE, MAX_UINT256),
              encodeSwap({
                poolId,
                kind: SwapKind.GivenIn,
                tokenIn: wstFUSE,
                tokenOut: WFUSE,
                amount: toChainedReference(0),
                sender: relayer,
                recipient: recipientUser,
                outputReference: 0,
              }),
            ])
          ).wait();
        });

        it('performs the given swap', async () => {
          expectEvent.inIndirectReceipt(receipt, vault.instance.interface, 'Swap', {
            poolId,
            tokenIn: wstFUSE.address,
            tokenOut: WFUSE.address,
          });

          expectTransferEvent(receipt, { from: vault.address, to: recipientUser.address }, WFUSE);
        });

        it('does not leave dust on the relayer', async () => {
          expect(await WFUSE.balanceOf(relayer)).to.be.eq(0);
          expect(await wstFUSE.balanceOf(relayer)).to.be.eq(0);
        });
      });

      describe('swap using stFUSE as an output', () => {
        let receipt: ContractReceipt;
        const amount = fp(1);

        sharedBeforeEach('swap WFUSE for stFUSE', async () => {
          receipt = await (
            await relayer.connect(senderUser).multicall([
              encodeSwap({
                poolId,
                kind: SwapKind.GivenIn,
                tokenIn: WFUSE,
                tokenOut: wstFUSE,
                amount,
                sender: senderUser,
                recipient: relayer,
                outputReference: toChainedReference(0),
              }),
              encodeUnwrap(relayer.address, recipientUser.address, toChainedReference(0)),
            ])
          ).wait();
        });

        it('performs the given swap', async () => {
          expectEvent.inIndirectReceipt(receipt, vault.instance.interface, 'Swap', {
            poolId,
            tokenIn: WFUSE.address,
            tokenOut: wstFUSE.address,
          });

          expectTransferEvent(receipt, { from: relayer.address, to: recipientUser.address }, stFUSE);
        });

        it('does not leave dust on the relayer', async () => {
          expect(await WFUSE.balanceOf(relayer)).to.be.eq(0);
          expect(await wstFUSE.balanceOf(relayer)).to.be.eq(0);
        });
      });
    });

    describe('batchSwap', () => {
      function encodeBatchSwap(params: {
        swaps: Array<{
          poolId: string;
          tokenIn: Token;
          tokenOut: Token;
          amount: BigNumberish;
        }>;
        sender: Account;
        recipient: Account;
        outputReferences?: Dictionary<BigNumberish>;
      }): string {
        const outputReferences = Object.entries(params.outputReferences ?? {}).map(([symbol, key]) => ({
          index: poolTokens.findIndexBySymbol(symbol),
          key,
        }));

        return relayerLibrary.interface.encodeFunctionData('batchSwap', [
          SwapKind.GivenIn,
          params.swaps.map((swap) => ({
            poolId: swap.poolId,
            assetInIndex: poolTokens.indexOf(swap.tokenIn),
            assetOutIndex: poolTokens.indexOf(swap.tokenOut),
            amount: swap.amount,
            userData: '0x',
          })),
          poolTokens.addresses,
          {
            sender: TypesConverter.toAddress(params.sender),
            recipient: TypesConverter.toAddress(params.recipient),
            fromInternalBalance: false,
            toInternalBalance: false,
          },
          new Array(poolTokens.length).fill(MAX_INT256),
          MAX_UINT256,
          0,
          outputReferences,
        ]);
      }

      describe('swap using stFUSE as an input', () => {
        let receipt: ContractReceipt;
        const amount = fp(1);

        sharedBeforeEach('swap stFUSE for WFUSE', async () => {
          receipt = await (
            await relayer.connect(senderUser).multicall([
              encodeWrap(senderUser.address, relayer.address, amount, toChainedReference(0)),
              encodeApprove(wstFUSE, MAX_UINT256),
              encodeBatchSwap({
                swaps: [{ poolId, tokenIn: wstFUSE, tokenOut: WFUSE, amount: toChainedReference(0) }],
                sender: relayer,
                recipient: recipientUser,
              }),
            ])
          ).wait();
        });

        it('performs the given swap', async () => {
          expectEvent.inIndirectReceipt(receipt, vault.instance.interface, 'Swap', {
            poolId: poolId,
            tokenIn: wstFUSE.address,
            tokenOut: WFUSE.address,
          });

          expectTransferEvent(receipt, { from: vault.address, to: recipientUser.address }, WFUSE);
        });

        it('does not leave dust on the relayer', async () => {
          expect(await WFUSE.balanceOf(relayer)).to.be.eq(0);
          expect(await wstFUSE.balanceOf(relayer)).to.be.eq(0);
        });
      });

      describe('swap using stFUSE as an output', () => {
        let receipt: ContractReceipt;
        const amount = fp(1);

        sharedBeforeEach('swap WFUSE for stFUSE', async () => {
          receipt = await (
            await relayer.connect(senderUser).multicall([
              encodeBatchSwap({
                swaps: [{ poolId, tokenIn: WFUSE, tokenOut: wstFUSE, amount }],
                sender: senderUser,
                recipient: relayer,
                outputReferences: { wstFUSE: toChainedReference(0) },
              }),
              encodeUnwrap(relayer.address, recipientUser.address, toChainedReference(0)),
            ])
          ).wait();
        });

        it('performs the given swap', async () => {
          expectEvent.inIndirectReceipt(receipt, vault.instance.interface, 'Swap', {
            poolId: poolId,
            tokenIn: WFUSE.address,
            tokenOut: wstFUSE.address,
          });

          expectTransferEvent(receipt, { from: relayer.address, to: recipientUser.address }, stFUSE);
        });

        it('does not leave dust on the relayer', async () => {
          expect(await WFUSE.balanceOf(relayer)).to.be.eq(0);
          expect(await wstFUSE.balanceOf(relayer)).to.be.eq(0);
        });
      });
    });

    describe('joinPool', () => {
      function encodeJoin(params: {
        poolId: string;
        sender: Account;
        recipient: Account;
        assets: TokenList;
        maxAmountsIn: BigNumberish[];
        userData: string;
        outputReference?: BigNumberish;
      }): string {
        return relayerLibrary.interface.encodeFunctionData('joinPool', [
          params.poolId,
          0, // WeightedPool
          TypesConverter.toAddress(params.sender),
          TypesConverter.toAddress(params.recipient),
          {
            assets: params.assets.addresses,
            maxAmountsIn: params.maxAmountsIn,
            userData: params.userData,
            fromInternalBalance: false,
          },
          0,
          params.outputReference ?? 0,
        ]);
      }

      let receipt: ContractReceipt;
      let senderWstFUSEBalanceBefore: BigNumber;
      const amount = fp(1);

      sharedBeforeEach('join the pool', async () => {
        senderWstFUSEBalanceBefore = await wstFUSE.balanceOf(senderUser);
        receipt = await (
          await relayer.connect(senderUser).multicall([
            encodeWrap(senderUser.address, relayer.address, amount, toChainedReference(0)),
            encodeApprove(wstFUSE, MAX_UINT256),
            encodeJoin({
              poolId,
              assets: poolTokens,
              sender: relayer,
              recipient: recipientUser,
              maxAmountsIn: poolTokens.map(() => MAX_UINT256),
              userData: WeightedPoolEncoder.joinExactTokensInForKPTOut(
                poolTokens.map((token) => (token === wstFUSE ? toChainedReference(0) : 0)),
                0
              ),
            }),
          ])
        ).wait();
      });

      it('joins the pool', async () => {
        expectEvent.inIndirectReceipt(receipt, vault.instance.interface, 'PoolBalanceChanged', {
          poolId,
          liquidityProvider: relayer.address,
        });

        // KPT minted to recipient
        expectTransferEvent(
          receipt,
          { from: ZERO_ADDRESS, to: recipientUser.address },
          await Token.deployedAt(pool.address)
        );
      });

      it('does not take wstFUSE from the user', async () => {
        const senderWstFUSEBalanceAfter = await wstFUSE.balanceOf(senderUser);
        expect(senderWstFUSEBalanceAfter).to.be.eq(senderWstFUSEBalanceBefore);
      });

      it('does not leave dust on the relayer', async () => {
        expect(await WFUSE.balanceOf(relayer)).to.be.eq(0);
        expect(await wstFUSE.balanceOf(relayer)).to.be.eq(0);
      });
    });
  });
});
