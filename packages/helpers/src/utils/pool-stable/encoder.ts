import { defaultAbiCoder } from '@ethersproject/abi';
import { BigNumberish } from '@ethersproject/bignumber';

export enum StablePoolJoinKind {
  INIT = 0,
  EXACT_TOKENS_IN_FOR_KPT_OUT,
  TOKEN_IN_FOR_EXACT_KPT_OUT,
}

export enum StablePhantomPoolJoinKind {
  INIT = 0,
  COLLECT_PROTOCOL_FEES,
}

export enum StablePoolExitKind {
  EXACT_KPT_IN_FOR_ONE_TOKEN_OUT = 0,
  EXACT_KPT_IN_FOR_TOKENS_OUT,
  KPT_IN_FOR_EXACT_TOKENS_OUT,
}

export class StablePoolEncoder {
  /**
   * Cannot be constructed.
   */
  private constructor() {
    // eslint-disable-next-line @typescript-eslint/no-empty-function
  }

  /**
   * Encodes the userData parameter for providing the initial liquidity to a StablePool
   * @param initialBalances - the amounts of tokens to send to the pool to form the initial balances
   */
  static joinInit = (amountsIn: BigNumberish[]): string =>
    defaultAbiCoder.encode(['uint256', 'uint256[]'], [StablePoolJoinKind.INIT, amountsIn]);

  /**
   * Encodes the userData parameter for collecting protocol fees for StablePhantomPool
   */
  static joinCollectProtocolFees = (): string =>
    defaultAbiCoder.encode(['uint256'], [StablePhantomPoolJoinKind.COLLECT_PROTOCOL_FEES]);

  /**
   * Encodes the userData parameter for joining a StablePool with exact token inputs
   * @param amountsIn - the amounts each of token to deposit in the pool as liquidity
   * @param minimumKPT - the minimum acceptable KPT to receive in return for deposited tokens
   */
  static joinExactTokensInForKPTOut = (amountsIn: BigNumberish[], minimumKPT: BigNumberish): string =>
    defaultAbiCoder.encode(
      ['uint256', 'uint256[]', 'uint256'],
      [StablePoolJoinKind.EXACT_TOKENS_IN_FOR_KPT_OUT, amountsIn, minimumKPT]
    );

  /**
   * Encodes the userData parameter for joining a StablePool with to receive an exact amount of KPT
   * @param bptAmountOut - the amount of KPT to be minted
   * @param enterTokenIndex - the index of the token to be provided as liquidity
   */
  static joinTokenInForExactKPTOut = (bptAmountOut: BigNumberish, enterTokenIndex: number): string =>
    defaultAbiCoder.encode(
      ['uint256', 'uint256', 'uint256'],
      [StablePoolJoinKind.TOKEN_IN_FOR_EXACT_KPT_OUT, bptAmountOut, enterTokenIndex]
    );

  /**
   * Encodes the userData parameter for exiting a StablePool by removing a single token in return for an exact amount of KPT
   * @param bptAmountIn - the amount of KPT to be burned
   * @param enterTokenIndex - the index of the token to removed from the pool
   */
  static exitExactKPTInForOneTokenOut = (bptAmountIn: BigNumberish, exitTokenIndex: number): string =>
    defaultAbiCoder.encode(
      ['uint256', 'uint256', 'uint256'],
      [StablePoolExitKind.EXACT_KPT_IN_FOR_ONE_TOKEN_OUT, bptAmountIn, exitTokenIndex]
    );

  /**
   * Encodes the userData parameter for exiting a StablePool by removing tokens in return for an exact amount of KPT
   * @param bptAmountIn - the amount of KPT to be burned
   */
  static exitExactKPTInForTokensOut = (bptAmountIn: BigNumberish): string =>
    defaultAbiCoder.encode(['uint256', 'uint256'], [StablePoolExitKind.EXACT_KPT_IN_FOR_TOKENS_OUT, bptAmountIn]);

  /**
   * Encodes the userData parameter for exiting a StablePool by removing exact amounts of tokens
   * @param amountsOut - the amounts of each token to be withdrawn from the pool
   * @param maxKPTAmountIn - the minimum acceptable KPT to burn in return for withdrawn tokens
   */
  static exitKPTInForExactTokensOut = (amountsOut: BigNumberish[], maxKPTAmountIn: BigNumberish): string =>
    defaultAbiCoder.encode(
      ['uint256', 'uint256[]', 'uint256'],
      [StablePoolExitKind.KPT_IN_FOR_EXACT_TOKENS_OUT, amountsOut, maxKPTAmountIn]
    );
}
