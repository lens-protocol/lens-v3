import {FixedImplementationContract, LensCreate2} from "@core/upgradeability/LensCreate2.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// This Mock is needed because vm.etch() not vm.deployTo() does not work on zkSync for now
contract MockLensCreate2 is LensCreate2 {
    address private _MOCK_FIXED_IMPLEMENTATION;
    bytes32 private _MOCK_PROXY_BYTECODE_HASH;
    bytes32 private _MOCK_SENDER_BYTES;
    bytes32 private _MOCK_CREATE2_PREFIX;
    bytes32 private _MOCK_CONSTRUCTOR_ARGS_HASH;

    constructor(address owner) LensCreate2(owner) {}

    function initialize(address owner) public {
        _MOCK_FIXED_IMPLEMENTATION = address(new FixedImplementationContract());
        address proxy = address(new TransparentUpgradeableProxy(FIXED_IMPLEMENTATION(), address(this), ""));
        bytes32 bytecodeHash;
        assembly {
            bytecodeHash := extcodehash(proxy)
        }
        _MOCK_PROXY_BYTECODE_HASH = bytecodeHash;
        _MOCK_CREATE2_PREFIX = keccak256("zksyncCreate2");
        _MOCK_SENDER_BYTES = bytes32(uint256(uint160(address(this))));
        _MOCK_CONSTRUCTOR_ARGS_HASH = keccak256(abi.encode(FIXED_IMPLEMENTATION(), address(this), ""));
        _transferOwnership(owner);
    }

    function FIXED_IMPLEMENTATION() public view override returns (address) {
        return _MOCK_FIXED_IMPLEMENTATION;
    }

    function PROXY_BYTECODE_HASH() public view override returns (bytes32) {
        return _MOCK_PROXY_BYTECODE_HASH;
    }

    function SENDER_BYTES() public view override returns (bytes32) {
        return _MOCK_SENDER_BYTES;
    }

    function CREATE2_PREFIX() public view override returns (bytes32) {
        return _MOCK_CREATE2_PREFIX;
    }

    function CONSTRUCTOR_ARGS_HASH() public view override returns (bytes32) {
        return _MOCK_CONSTRUCTOR_ARGS_HASH;
    }
}
