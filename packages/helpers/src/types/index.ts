import { BigNumberish } from '../numbers';

export type BatchSwapStep = {
  poolId: string;
  assetInIndex: number;
  assetOutIndex: number;
  amount: BigNumberish;
  userData: string;
};

export enum SwapKind {
  GivenIn = 0,
  GivenOut,
}
