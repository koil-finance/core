import { defaultAbiCoder } from '@ethersproject/abi';
import { BigNumberish } from '@ethersproject/bignumber';

export enum WeightedPoolJoinKind {
  INIT = 0,
  EXACT_TOKENS_IN_FOR_KPT_OUT,
  TOKEN_IN_FOR_EXACT_KPT_OUT,
  ALL_TOKENS_IN_FOR_EXACT_KPT_OUT,
}

export enum WeightedPoolExitKind {
  EXACT_KPT_IN_FOR_ONE_TOKEN_OUT = 0,
  EXACT_KPT_IN_FOR_TOKENS_OUT,
  KPT_IN_FOR_EXACT_TOKENS_OUT,
  MANAGEMENT_FEE_TOKENS_OUT,
}

export class WeightedPoolEncoder {
  /**
   * Cannot be constructed.
   */
  private constructor() {
    // eslint-disable-next-line @typescript-eslint/no-empty-function
  }

  /**
   * Encodes the userData parameter for providing the initial liquidity to a WeightedPool
   * @param initialBalances - the amounts of tokens to send to the pool to form the initial balances
   */
  static joinInit = (amountsIn: BigNumberish[]): string =>
    defaultAbiCoder.encode(['uint256', 'uint256[]'], [WeightedPoolJoinKind.INIT, amountsIn]);

  /**
   * Encodes the userData parameter for joining a WeightedPool with exact token inputs
   * @param amountsIn - the amounts each of token to deposit in the pool as liquidity
   * @param minimumKPT - the minimum acceptable KPT to receive in return for deposited tokens
   */
  static joinExactTokensInForKPTOut = (amountsIn: BigNumberish[], minimumKPT: BigNumberish): string =>
    defaultAbiCoder.encode(
      ['uint256', 'uint256[]', 'uint256'],
      [WeightedPoolJoinKind.EXACT_TOKENS_IN_FOR_KPT_OUT, amountsIn, minimumKPT]
    );

  /**
   * Encodes the userData parameter for joining a WeightedPool with a single token to receive an exact amount of KPT
   * @param bptAmountOut - the amount of KPT to be minted
   * @param enterTokenIndex - the index of the token to be provided as liquidity
   */
  static joinTokenInForExactKPTOut = (bptAmountOut: BigNumberish, enterTokenIndex: number): string =>
    defaultAbiCoder.encode(
      ['uint256', 'uint256', 'uint256'],
      [WeightedPoolJoinKind.TOKEN_IN_FOR_EXACT_KPT_OUT, bptAmountOut, enterTokenIndex]
    );

  /**
   * Encodes the userData parameter for joining a WeightedPool proportionally to receive an exact amount of KPT
   * @param bptAmountOut - the amount of KPT to be minted
   */
  static joinAllTokensInForExactKPTOut = (bptAmountOut: BigNumberish): string =>
    defaultAbiCoder.encode(
      ['uint256', 'uint256'],
      [WeightedPoolJoinKind.ALL_TOKENS_IN_FOR_EXACT_KPT_OUT, bptAmountOut]
    );

  /**
   * Encodes the userData parameter for exiting a WeightedPool by removing a single token in return for an exact amount of KPT
   * @param bptAmountIn - the amount of KPT to be burned
   * @param enterTokenIndex - the index of the token to removed from the pool
   */
  static exitExactKPTInForOneTokenOut = (bptAmountIn: BigNumberish, exitTokenIndex: number): string =>
    defaultAbiCoder.encode(
      ['uint256', 'uint256', 'uint256'],
      [WeightedPoolExitKind.EXACT_KPT_IN_FOR_ONE_TOKEN_OUT, bptAmountIn, exitTokenIndex]
    );

  /**
   * Encodes the userData parameter for exiting a WeightedPool by removing tokens in return for an exact amount of KPT
   * @param bptAmountIn - the amount of KPT to be burned
   */
  static exitExactKPTInForTokensOut = (bptAmountIn: BigNumberish): string =>
    defaultAbiCoder.encode(['uint256', 'uint256'], [WeightedPoolExitKind.EXACT_KPT_IN_FOR_TOKENS_OUT, bptAmountIn]);

  /**
   * Encodes the userData parameter for exiting a WeightedPool by removing exact amounts of tokens
   * @param amountsOut - the amounts of each token to be withdrawn from the pool
   * @param maxKPTAmountIn - the minimum acceptable KPT to burn in return for withdrawn tokens
   */
  static exitKPTInForExactTokensOut = (amountsOut: BigNumberish[], maxKPTAmountIn: BigNumberish): string =>
    defaultAbiCoder.encode(
      ['uint256', 'uint256[]', 'uint256'],
      [WeightedPoolExitKind.KPT_IN_FOR_EXACT_TOKENS_OUT, amountsOut, maxKPTAmountIn]
    );
}

export class ManagedPoolEncoder {
  /**
   * Cannot be constructed.
   */
  private constructor() {
    // eslint-disable-next-line @typescript-eslint/no-empty-function
  }

  /**
   * Encodes the userData parameter for exiting a ManagedPool for withdrawing management fees.
   * This can only be done by the pool owner.
   */
  static exitForManagementFees = (): string =>
    defaultAbiCoder.encode(['uint256'], [WeightedPoolExitKind.MANAGEMENT_FEE_TOKENS_OUT]);
}
