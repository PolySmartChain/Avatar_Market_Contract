import { ethers, upgrades } from 'hardhat'
import { Contract, BigNumber, utils} from 'ethers'
import fs = require('fs')
import path = require('path')
import { check } from 'prettier';

//npx hardhat run scripts/deploy.ts

const defaultGasOptions = {
    gasLimit: 10000000,
    gasPrice: '3000000000'
};
  
export async function _deploy(id: string, name: string, args: any[], gasOptions = defaultGasOptions): Promise<Contract> {
    const lib = await ethers.getContractFactory(name);
    const r = await lib.deploy(...args, gasOptions);
    await r.deployed(); // 等待部署完成
    console.log(`${name} deployed at: ${r.address}`);
    return r;
}

interface Data {
    Market: Contract
}

async function main() {
    const socialVault = "0x44f057bBfc00df47DCE08fD3D7E892943ae90Aac";
    const owner = "0x73254a360C19e3608620d3CEd32eC3654F0ae520";
    const polyjebClub = "0x63f158Eb42a417Aa8CA43F775b221161f391783b";

    const checker = await _deploy('TokenExistenceChecker', 'TokenExistenceChecker', [polyjebClub])


    let ret: Data = <any>{}
    const mcProxy = await ethers.getContractFactory("ExchangeCore")
    const deployOptions = {
        initializer: 'initialize',
        ...defaultGasOptions
    };
    ret.Market = await upgrades.deployProxy(mcProxy, [socialVault], deployOptions)
    const market = await ret.Market.deployed()
    console.log(ret.Market.address, " ExchangeCore(proxy) address")
    console.log(await upgrades.erc1967.getImplementationAddress(ret.Market.address), " getImplementationAddress")
    
    // await market.transferOwnership(owner,{
    //     ...defaultGasOptions
    // })
   
    console.log({
        TokenExistenceChecker: checker.address,
        Market: market.address,
    })
}

main().catch(console.error)
