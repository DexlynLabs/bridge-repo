import { ethers } from 'ethers';

import {
  ChainMap,
  OwnableConfig,
  TokenRouterConfig,
  TokenType,
  buildAggregationIsmConfigs,
  defaultMultisigConfigs,
} from '@hyperlane-xyz/sdk';

import {
  RouterConfigWithoutOwner,
  tokens,
} from '../../../../../src/config/warp.js';

export const getTest1EthereumUSDCWarpConfig = async (
  routerConfig: ChainMap<RouterConfigWithoutOwner>,
  abacusWorksEnvOwnerConfig: ChainMap<OwnableConfig>,
): Promise<ChainMap<TokenRouterConfig>> => {
  const ismConfig = buildAggregationIsmConfigs(
    'test1',
    [],
    defaultMultisigConfigs,
  ).test1;

  const test1: TokenRouterConfig = {
    ...routerConfig.test1,
    ...abacusWorksEnvOwnerConfig.test1,
    type: TokenType.synthetic,
    symbol: 'FUSDC',
    totalSupply: 0,
    name: 'Fake USDC',
    decimals: 6,
    interchainSecurityModule: ismConfig,
  };

  return {
    test1,
  };
};
