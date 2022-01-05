import TokenList from '../tokens/TokenList';
import Token from '../tokens/Token';
import { BatchSwapStep } from '../../types';

export type Trade = {
  poolId: string;
  tokenIn: Token;
  tokenOut: Token;
  amount?: number | string;
};

export function getTokensSwaps(tokens: TokenList, trades: Array<Trade>): [Array<string>, Array<BatchSwapStep>] {
  const swaps: Array<BatchSwapStep> = [];

  const tokenAddresses = Array.from(
    new Set(trades.reduce((acc: string[], trade) => acc.concat([trade.tokenIn.address, trade.tokenOut.address]), []))
  );

  for (const trade of trades) {
    const assetInIndex = tokens.indexOf(trade.tokenIn);
    const assetOutIndex = tokens.indexOf(trade.tokenOut);

    swaps.push({
      poolId: trade.poolId,
      assetInIndex,
      assetOutIndex,
      amount: trade.amount?.toString() ?? 0,
      userData: '0x',
    });
  }

  return [tokenAddresses, swaps];
}
