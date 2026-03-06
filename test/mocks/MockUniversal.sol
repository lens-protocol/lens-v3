// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

contract MockUniversal {
    bool _revertNextCall;
    string _errorMessage;

    function mockToSucceedOnNextCall() external {
        _revertNextCall = false;
    }

    function mockToRevertOnNextCall() external {
        _revertNextCall = true;
    }

    function mockToRevertOnNextCallWith(bytes4 errorSelector) external {
        _revertNextCall = true;
        bytes memory errorSelectorAsBytes = new bytes(4);
        for (uint256 i = 0; i < 4; i++) {
            errorSelectorAsBytes[i] = bytes4(errorSelector)[i];
        }
        _errorMessage = string(errorSelectorAsBytes);
    }

    function mockToRevertOnNextCallWith(string memory errorMessage) external {
        _revertNextCall = true;
        _errorMessage = errorMessage;
    }

    fallback() external {
        if (_revertNextCall) {
            delete _revertNextCall;
            if (bytes(_errorMessage).length == 0) {
                revert();
            } else {
                string memory errorMessage = _errorMessage;
                delete _errorMessage;
                revert(errorMessage);
            }
        }
    }
}
