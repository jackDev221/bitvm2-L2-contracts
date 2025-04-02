const {expect} = require("chai");


const BTCAddressTypeEnum = {
    Legacy: 0,
    SegWit: 1,
    NativeSegWit: 2,
    Taproot: 3
}

const NetworkTypeEnum = {
    Mainnet: 0,
    Testnet: 1

}


describe("GoatHTLC contract", function () {
    let MToken;
    let MTokenContract;
    let GoatHTLC;
    let GoatHTLCContract;
    let owner;
    let addr1;
    let addr2;
    let transferInEvent;
    let preimage;
    let time_lock = 20;

    beforeEach(async function () {
        GoatHTLC = await ethers.getContractFactory("GoatHTLC");
        MToken = await ethers.getContractFactory("MToken");
        [owner, addr1, addr2] = await ethers.getSigners();
        GoatHTLCContract = await GoatHTLC.deploy();
        MTokenContract = await MToken.deploy(
            "MToken",
            "MT",
            ethers.utils.parseEther("1000000"),
            owner.address
        );
        console.log("GoatHTLCContractAddress", GoatHTLCContract.address);
        console.log("MTokenAddress", MTokenContract.address);
        console.log("owner", owner.address);
        console.log("addr1", addr1.address);
        console.log("addr2", addr2.address);
        console.log("owner allow contract: ", await MTokenContract.allowance(owner.address, GoatHTLCContract.address));
        await MTokenContract.approve(GoatHTLCContract.address, ethers.utils.parseEther("100"));
        console.log("addr1 token balance", await MTokenContract.balanceOf(addr1.address));
        preimage = ethers.utils.formatBytes32String("Hello world");
        const hashLock = solidityKeccak256(preimage);
        console.log("Hash:", hashLock);
        const currentTimestamp = Math.floor(Date.now() / 1000);
        console.log(currentTimestamp)

        const transferInParams = {
            dstEthAddr: addr1.address,
            token: MTokenContract.address,
            amount: ethers.utils.parseEther("10"),
            secretLength: 32,
            hashLock: hashLock,
            timeLock: currentTimestamp + time_lock,
            network: NetworkTypeEnum.Testnet,
            addrType: BTCAddressTypeEnum.Legacy,
            claimBtcAddr: "miJ19RACTc7Sow64gbznCnCz3p4Ey2NP18",
        }

        console.log(transferInParams)

        const tx0 = await GoatHTLCContract.connect(addr1).registerBTCAddress(
            NetworkTypeEnum.Testnet,
            BTCAddressTypeEnum.Legacy,
            "miJ19RACTc7Sow64gbznCnCz3p4Ey2NP18"
        );
        console.log("register BTC address txHash", tx0.hash);

        const tx = await GoatHTLCContract.transferIn(
            transferInParams
        );
        console.log("transferIn txHash", tx0.hash);
        const receipt = await tx.wait();
        transferInEvent = receipt.events?.find((e) => e.event === "LogNewTransferIn");

    });

    describe("testFunction", function () {
        it("test_claim", async function () {
            console.log("========================================================");
            console.log("before claim GoatHTLCContract token balance", await MTokenContract.balanceOf(GoatHTLCContract.address));
            console.log("before claim  token balance", await MTokenContract.balanceOf(addr1.address));
            if (transferInEvent) {
                const transferID = transferInEvent?.args?.transferId;
                console.log("transferID", transferID)
                console.log("sender", transferInEvent?.args?.sender);
                console.log("receiver", transferInEvent?.args?.receiver);
                console.log("token", transferInEvent?.args?.token);
                console.log("amount", transferInEvent?.args?.amount);
                console.log("refundBtcAddr", transferInEvent?.args?.refundBtcAddr);
                console.log("GoatHTLCContract token balance", await MTokenContract.balanceOf(GoatHTLCContract.address));
                const tx = await GoatHTLCContract.claim(
                    transferID,
                    preimage
                );
            } else {
                console.log("not found");
            }
            console.log("GoatHTLCContract token balance", await MTokenContract.balanceOf(GoatHTLCContract.address));
            console.log("addr1 token balance", await MTokenContract.balanceOf(addr1.address));
            console.log("========================================================");
        });

        it("test_redeem", async function () {
            console.log("========================================================");
            console.log("before GoatHTLCContract token balance", await MTokenContract.balanceOf(GoatHTLCContract.address));
            console.log("before owner token balance", await MTokenContract.balanceOf(owner.address));

            if (transferInEvent) {
                const transferID = transferInEvent?.args?.transferId;
                console.log("transferID", transferID)
                console.log("sender", transferInEvent?.args?.sender);
                console.log("receiver", transferInEvent?.args?.receiver);
                console.log("=====> start redeem");
                console.log("GoatHTLCContract token balance", await MTokenContract.balanceOf(GoatHTLCContract.address));
                console.log("owner token balance", await MTokenContract.balanceOf(owner.address));
                console.log("start sleep at", Math.floor(Date.now() / 1000))
                await sleep(time_lock + 12);
                console.log("finish sleep at", Math.floor(Date.now() / 1000))
                const tx = await GoatHTLCContract.refund(
                    transferID
                );
            } else {
                console.log("not found");
            }
            console.log("GoatHTLCContract token balance", await MTokenContract.balanceOf(GoatHTLCContract.address));
            console.log("owner token balance", await MTokenContract.balanceOf(owner.address));
        });
        console.log("========================================================");
    });


});

function solidityKeccak256(preimage) {
    const packed = ethers.utils.solidityPack(["bytes"], [preimage]);
    return ethers.utils.keccak256(packed);
}

async function getLatestBlockTime() {
    console.log("dd")
    const provider = ethers.getDefaultProvider();
    console.log("dd")
    const block = await provider.getBlock('latest');
    console.log("bbb", block)
    return block.timestamp; 
}

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms * 1000));
}
