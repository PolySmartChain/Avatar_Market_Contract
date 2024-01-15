import { ethers, upgrades } from 'hardhat'
import { Contract, BigNumber, utils} from 'ethers'
import fs = require('fs')
import path = require('path')

//npx hardhat run scripts/deploy.ts

export async function _deploy(id: string, name: string, args: any[]): Promise<Contract> {
    const lib = await ethers.getContractFactory(name)
    const r = await lib.deploy(...args)
    return r
}

interface Data {
    Market: Contract
}

async function main() {
    // const [signer] = await ethers.getSigners()
    
    let socialVault = "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"

    let ret: Data = <any>{}
    const mcProxy = await ethers.getContractFactory("ExchangeCore")
    ret.Market = await upgrades.deployProxy(mcProxy, [socialVault], {initializer: 'initialize'})
    const market = await ret.Market.deployed()
    console.log(ret.Market.address, " ExchangeCore(proxy) address")
    console.log(await upgrades.erc1967.getImplementationAddress(ret.Market.address), " getImplementationAddress")

   
    console.log({
        Market: market.address,
    })
}

main().catch(console.error)
