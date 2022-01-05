import { Contract } from 'ethers';

import * as expectEvent from '../../../test/expectEvent';
import { deploy, deployedAt } from '../../../contract';

import Vault from '../../vault/Vault';
import WeightedPool from './WeightedPool';
import VaultDeployer from '../../vault/VaultDeployer';
import TypesConverter from '../../types/TypesConverter';
import {
  BasePoolRights,
  ManagedPoolParams,
  ManagedPoolRights,
  RawWeightedPoolDeployment,
  WeightedPoolDeployment,
  WeightedPoolType,
} from './types';
import { ZERO_ADDRESS } from '../../../constants';
import { MONTH, DAY } from '../../../time';

const NAME = 'Koil Pool Token';
const SYMBOL = 'KPT';

export default {
  async deploy(params: RawWeightedPoolDeployment): Promise<WeightedPool> {
    const deployment = TypesConverter.toWeightedPoolDeployment(params);
    const vault = params?.vault ?? (await VaultDeployer.deploy(TypesConverter.toRawVaultDeployment(params)));
    const pool = await (params.fromFactory ? this._deployFromFactory : this._deployStandalone)(deployment, vault);

    const {
      tokens,
      weights,
      assetManagers,
      swapFeePercentage,
      poolType,
      swapEnabledOnStart,
      mustAllowlistLPs,
      managementSwapFeePercentage,
    } = deployment;

    const poolId = await pool.getPoolId();
    return new WeightedPool(
      pool,
      poolId,
      vault,
      tokens,
      weights,
      assetManagers,
      swapFeePercentage,
      poolType,
      swapEnabledOnStart,
      mustAllowlistLPs,
      managementSwapFeePercentage
    );
  },

  async _deployStandalone(params: WeightedPoolDeployment, vault: Vault): Promise<Contract> {
    const {
      tokens,
      weights,
      assetManagers,
      swapFeePercentage,
      pauseWindowDuration,
      bufferPeriodDuration,
      oracleEnabled,
      poolType,
      swapEnabledOnStart,
      mustAllowlistLPs,
      managementSwapFeePercentage,
      owner,
      from,
    } = params;

    let result: Promise<Contract>;

    switch (poolType) {
      case WeightedPoolType.WEIGHTED_POOL_2TOKENS: {
        result = deploy('pool-weighted/MockWeightedPool2Tokens', {
          args: [
            {
              vault: vault.address,
              name: NAME,
              symbol: SYMBOL,
              token0: tokens.addresses[0],
              token1: tokens.addresses[1],
              normalizedWeight0: weights[0],
              normalizedWeight1: weights[1],
              swapFeePercentage: swapFeePercentage,
              pauseWindowDuration: pauseWindowDuration,
              bufferPeriodDuration: bufferPeriodDuration,
              oracleEnabled: oracleEnabled,
              owner: owner,
            },
          ],
          from,
          libraries: { QueryProcessor: (await deploy('QueryProcessor')).address },
        });
        break;
      }
      case WeightedPoolType.LIQUIDITY_BOOTSTRAPPING_POOL: {
        result = deploy('pool-weighted/LiquidityBootstrappingPool', {
          args: [
            vault.address,
            NAME,
            SYMBOL,
            tokens.addresses,
            weights,
            swapFeePercentage,
            pauseWindowDuration,
            bufferPeriodDuration,
            owner,
            swapEnabledOnStart,
          ],
          from,
        });
        break;
      }
      case WeightedPoolType.MANAGED_POOL: {
        result = deploy('pool-weighted/ManagedPool', {
          args: [
            {
              vault: vault.address,
              name: NAME,
              symbol: SYMBOL,
              tokens: tokens.addresses,
              normalizedWeights: weights,
              swapFeePercentage: swapFeePercentage,
              assetManagers: assetManagers,
              pauseWindowDuration: pauseWindowDuration,
              bufferPeriodDuration: bufferPeriodDuration,
              owner: owner,
              swapEnabledOnStart: swapEnabledOnStart,
              mustAllowlistLPs: mustAllowlistLPs,
              managementSwapFeePercentage: managementSwapFeePercentage,
            },
          ],
          from,
        });
        break;
      }
      default: {
        result = deploy('pool-weighted/WeightedPool', {
          args: [
            vault.address,
            NAME,
            SYMBOL,
            tokens.addresses,
            weights,
            assetManagers,
            swapFeePercentage,
            pauseWindowDuration,
            bufferPeriodDuration,
            owner,
          ],
          from,
        });
      }
    }

    return result;
  },

  async _deployFromFactory(params: WeightedPoolDeployment, vault: Vault): Promise<Contract> {
    const {
      tokens,
      weights,
      assetManagers,
      swapFeePercentage,
      oracleEnabled,
      swapEnabledOnStart,
      mustAllowlistLPs,
      managementSwapFeePercentage,
      poolType,
      owner,
      from,
    } = params;

    let result: Promise<Contract>;

    switch (poolType) {
      case WeightedPoolType.WEIGHTED_POOL_2TOKENS: {
        const factory = await deploy('pool-weighted/WeightedPool2TokensFactory', {
          args: [vault.address],
          from,
          libraries: { QueryProcessor: await (await deploy('QueryProcessor')).address },
        });
        const tx = await factory.create(
          NAME,
          SYMBOL,
          tokens.addresses,
          weights,
          swapFeePercentage,
          oracleEnabled,
          owner
        );
        const receipt = await tx.wait();
        const event = expectEvent.inReceipt(receipt, 'PoolCreated');
        result = deployedAt('pool-weighted/WeightedPool2Tokens', event.args.pool);
        break;
      }
      case WeightedPoolType.LIQUIDITY_BOOTSTRAPPING_POOL: {
        const factory = await deploy('pool-weighted/LiquidityBootstrappingPoolFactory', {
          args: [vault.address],
          from,
        });
        const tx = await factory.create(
          NAME,
          SYMBOL,
          tokens.addresses,
          weights,
          swapFeePercentage,
          owner,
          swapEnabledOnStart
        );
        const receipt = await tx.wait();
        const event = expectEvent.inReceipt(receipt, 'PoolCreated');
        result = deployedAt('pool-weighted/LiquidityBootstrappingPool', event.args.pool);
        break;
      }
      case WeightedPoolType.MANAGED_POOL: {
        const baseFactory = await deploy('pool-weighted/BaseManagedPoolFactory', {
          args: [vault.address],
          from,
        });

        const factory = await deploy('pool-weighted/ManagedPoolFactory', {
          args: [baseFactory.address],
          from,
        });

        const newPoolParams: ManagedPoolParams = {
          vault: vault.address,
          name: NAME,
          symbol: SYMBOL,
          tokens: tokens.addresses,
          normalizedWeights: weights,
          assetManagers: Array(tokens.length).fill(ZERO_ADDRESS),
          swapFeePercentage: swapFeePercentage,
          pauseWindowDuration: MONTH * 3,
          bufferPeriodDuration: MONTH,
          owner: from?.address || ZERO_ADDRESS,
          swapEnabledOnStart: swapEnabledOnStart,
          mustAllowlistLPs: mustAllowlistLPs,
          managementSwapFeePercentage: managementSwapFeePercentage,
        };

        const basePoolRights: BasePoolRights = {
          canTransferOwnership: true,
          canChangeSwapFee: true,
          canUpdateMetadata: true,
        };

        const managedPoolRights: ManagedPoolRights = {
          canChangeWeights: true,
          canDisableSwaps: true,
          canSetMustAllowlistLPs: true,
          canSetCircuitBreakers: true,
          canChangeTokens: true,
        };

        const tx = await factory
          .connect(from || ZERO_ADDRESS)
          .create(newPoolParams, basePoolRights, managedPoolRights, DAY);
        const receipt = await tx.wait();
        const event = expectEvent.inReceipt(receipt, 'ManagedPoolCreated');
        result = deployedAt('pool-weighted/ManagedPool', event.args.pool);
        break;
      }
      default: {
        const factory = await deploy('pool-weighted/WeightedPoolFactory', { args: [vault.address], from });
        const tx = await factory.create(
          NAME,
          SYMBOL,
          tokens.addresses,
          weights,
          assetManagers,
          swapFeePercentage,
          owner
        );
        const receipt = await tx.wait();
        const event = expectEvent.inReceipt(receipt, 'PoolCreated');
        result = deployedAt('pool-weighted/WeightedPool', event.args.pool);
      }
    }

    return result;
  },
};
