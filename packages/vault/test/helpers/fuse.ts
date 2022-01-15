import { deploy } from '@koil-finance/helpers/src/contract';
import { BigNumberish, bn } from '@koil-finance/helpers/src/numbers';
import { Account } from '@koil-finance/helpers/src/models/types/types';
import TypesConverter from '@koil-finance/helpers/src/models/types/TypesConverter';

export async function forceSendFuse(recipient: Account, amount: BigNumberish): Promise<void> {
  await deploy('FuseForceSender', { args: [TypesConverter.toAddress(recipient), { value: bn(amount) }] });
}
