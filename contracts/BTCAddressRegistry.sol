pragma solidity >=0.8.0 <0.9.0;
contract BTCAddressRegistry {
    enum BTCAddressType {
        Legacy,     // P2PKH start with (mainnet: 1 ; testnet m | n)
        SegWit,      // P2SH-P2WPKH start with (mainnet: 3 ; testnet 2)
        NativeSegWit, // P2WPKH start with (mainnet: bc1 ; testnet tb1)
        Taproot      // P2TR start with (mainnet: bc1p ; testnet tb1p)
    }

    enum NetworkType {
        Mainnet,
        Testnet
    }

    struct BTCAddressInfo {
        string legacyMainnet;
        string segwitMainnet;
        string nativeSegwitMainnet;
        string taprootMainnet;
        string legacyTestnet;
        string segwitTestnet;
        string nativeSegwitTestnet;
        string taprootTestnet;
    }

    mapping(address => BTCAddressInfo) private ethToBtc;

    event BTCAddressRegistered(
        address indexed ethAddress,
        NetworkType network,
        BTCAddressType addrType,
        string btcAddress
    );

    modifier notEmpty(string memory btcAddr) {
        require(bytes(btcAddr).length > 0, "BTC address cannot be empty");
        _;
    }

    modifier validAddress(BTCAddressType addrType, NetworkType network, string calldata btcAddr) {
        bytes memory addrBytes = bytes(btcAddr);
        require(addrBytes.length >= 26, "BTC address length not less 26");

        bool isValid = false;
        uint prefixLength = 0;

        if (addrType == BTCAddressType.Legacy) {
            if (network == NetworkType.Mainnet) {
                isValid = (addrBytes[0] == '1');
            } else {
                isValid = (addrBytes[0] == 'm' || addrBytes[0] == 'n');
            }
            isValid = (isValid && addrBytes.length <= 34);
            prefixLength = 1;
        } else if (addrType == BTCAddressType.SegWit) {
            if (network == NetworkType.Mainnet) {
                isValid = (addrBytes[0] == '3');
            } else {
                isValid = (addrBytes[0] == '2');
            }
            isValid = (isValid && addrBytes.length <= 34);
            prefixLength = 1;
        } else if (addrType == BTCAddressType.NativeSegWit) {
            if (network == NetworkType.Mainnet) {
                isValid = (addrBytes[0] == 'b' &&
                addrBytes[1] == 'c' &&
                addrBytes[2] == '1' &&
                    addrBytes[3] != 'p');
            } else {
                isValid = (addrBytes[0] == 't' &&
                addrBytes[1] == 'b' &&
                addrBytes[2] == '1' &&
                    addrBytes[3] != 'p');
            }
            isValid = (isValid && addrBytes.length >= 42 && addrBytes.length <= 62);
            prefixLength = 3;

        } else if (addrType == BTCAddressType.Taproot) {
            if (network == NetworkType.Mainnet) {
                isValid = (addrBytes.length >= 4 &&
                addrBytes[0] == 'b' &&
                addrBytes[1] == 'c' &&
                addrBytes[2] == '1' &&
                    addrBytes[3] == 'p');
            } else {
                isValid = (addrBytes.length >= 4 &&
                addrBytes[0] == 't' &&
                addrBytes[1] == 'b' &&
                addrBytes[2] == '1' &&
                    addrBytes[3] == 'p');
            }
            isValid = (isValid && addrBytes.length == 62);
            prefixLength = 4;
        }
        if (isValid) {
            for (uint i = prefixLength; i < addrBytes.length; i++) {
                bytes1 char = addrBytes[i];
                bool isLowercase = (char >= 0x61 && char <= 0x7A); // a-z
                bool isUppercase = (char >= 0x41 && char <= 0x5A); // A-Z
                bool isDigit = (char >= 0x30 && char <= 0x39); // 0-9
                if (!(isLowercase || isUppercase || isDigit)) {
                    isValid = false;
                    break;
                }
            }
        }

        require(isValid, "BTC address does not match the specified type and network");
        _;
    }

    //
    function registerBTCAddress(
        NetworkType network,
        BTCAddressType addrType,
        string calldata btcAddr
    ) external validAddress(addrType, network, btcAddr) {
        BTCAddressInfo storage info = ethToBtc[msg.sender];

        if (network == NetworkType.Mainnet) {
            if (addrType == BTCAddressType.Legacy) {
                require(bytes(info.legacyMainnet).length == 0, "Mainnet Legacy address already registered");
                info.legacyMainnet = btcAddr;
            } else if (addrType == BTCAddressType.SegWit) {
                require(bytes(info.segwitMainnet).length == 0, "Mainnet SegWit address already registered");
                info.segwitMainnet = btcAddr;
            } else if (addrType == BTCAddressType.NativeSegWit) {
                require(bytes(info.nativeSegwitMainnet).length == 0, "Mainnet Native SegWit address already registered");
                info.nativeSegwitMainnet = btcAddr;
            } else if (addrType == BTCAddressType.Taproot) {
                require(bytes(info.taprootMainnet).length == 0, "Mainnet Taproot address already registered");
                info.taprootMainnet = btcAddr;
            }
        } else {
            if (addrType == BTCAddressType.Legacy) {
                require(bytes(info.legacyTestnet).length == 0, "Testnet Legacy address already registered");
                info.legacyTestnet = btcAddr;
            } else if (addrType == BTCAddressType.SegWit) {
                require(bytes(info.segwitTestnet).length == 0, "Testnet SegWit address already registered");
                info.segwitTestnet = btcAddr;
            } else if (addrType == BTCAddressType.NativeSegWit) {
                require(bytes(info.nativeSegwitTestnet).length == 0, "Testnet Native SegWit address already registered");
                info.nativeSegwitTestnet = btcAddr;
            } else if (addrType == BTCAddressType.Taproot) {
                require(bytes(info.taprootTestnet).length == 0, "Testnet Taproot address already registered");
                info.taprootTestnet = btcAddr;
            }
        }

        emit BTCAddressRegistered(msg.sender, network, addrType, btcAddr);
    }

    function getBTCAddresses(address ethAddr) external view returns (
        string memory legacyMainnet,
        string memory segwitMainnet,
        string memory nativeSegwitMainnet,
        string memory taprootMainnet,
        string memory legacyTestnet,
        string memory segwitTestnet,
        string memory nativeSegwitTestnet,
        string memory taprootTestnet
    ) {
        BTCAddressInfo memory info = ethToBtc[ethAddr];
        return (
            info.legacyMainnet,
            info.segwitMainnet,
            info.nativeSegwitMainnet,
            info.taprootMainnet,
            info.legacyTestnet,
            info.segwitTestnet,
            info.nativeSegwitTestnet,
            info.taprootTestnet
        );
    }

    function getBTCAddressByType(
        address ethAddr,
        NetworkType network,
        BTCAddressType addrType
    ) internal view returns (string memory) {
        BTCAddressInfo memory info = ethToBtc[ethAddr];

        if (network == NetworkType.Mainnet) {
            if (addrType == BTCAddressType.Legacy) {
                return info.legacyMainnet;
            } else if (addrType == BTCAddressType.SegWit) {
                return info.segwitMainnet;
            } else if (addrType == BTCAddressType.NativeSegWit) {
                return info.nativeSegwitMainnet;
            } else if (addrType == BTCAddressType.Taproot) {
                return info.taprootMainnet;
            }
        } else {
            if (addrType == BTCAddressType.Legacy) {
                return info.legacyTestnet;
            } else if (addrType == BTCAddressType.SegWit) {
                return info.segwitTestnet;
            } else if (addrType == BTCAddressType.NativeSegWit) {
                return info.nativeSegwitTestnet;
            } else if (addrType == BTCAddressType.Taproot) {
                return info.taprootTestnet;
            }
        }

        return "";
    }

    modifier validateAddressWithNetwork(NetworkType network, string memory btcAddr) {
        bytes memory addrBytes = bytes(btcAddr);
        require(addrBytes.length >= 26, "BTC address length not less 26");
        bool isValid = false;
        uint prefixLength = 0;

        if (network == NetworkType.Mainnet) {
            if (addrBytes[0] == '1' || addrBytes[0] == '3') {
                isValid = addrBytes.length <= 34;
                prefixLength = 1;
            } else if (addrBytes[0] == 'b' && addrBytes[1] == 'c' && addrBytes[2] == '1') {
                if (addrBytes[3] == 'p') {
                    isValid = addrBytes.length == 62;
                    prefixLength = 4;
                } else {
                    isValid = addrBytes.length >= 42 && addrBytes.length <= 62;
                    prefixLength = 3;
                }
            }
        } else {
            if (addrBytes[0] == 'm' || addrBytes[0] == 'n' || addrBytes[0] == '2') {
                isValid = addrBytes.length <= 34;
                prefixLength = 1;
            } else if (addrBytes[0] == 't' && addrBytes[1] == 'b' && addrBytes[2] == '1') {
                if (addrBytes[3] == 'p') {
                    isValid = addrBytes.length == 62;
                    prefixLength = 4;
                } else {
                    isValid = addrBytes.length >= 42 && addrBytes.length <= 62;
                    prefixLength = 3;
                }
            }
        }
        if (isValid) {
            for (uint i = prefixLength; i < addrBytes.length; i++) {
                bytes1 char = addrBytes[i];
                bool isLowercase = (char >= 0x61 && char <= 0x7A); // a-z
                bool isUppercase = (char >= 0x41 && char <= 0x5A); // A-Z
                bool isDigit = (char >= 0x30 && char <= 0x39); // 0-9
                // 不允许使用容易混淆的字符：0/O, 1/I/l

                if (!(isLowercase || isUppercase || isDigit)) {
                    isValid = false;
                    break;
                }
            }
        }

        require(isValid, "BTC address does not match the specified network");
        _;
    }
}
