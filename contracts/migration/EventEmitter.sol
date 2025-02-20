// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

struct Log1EventData {
    bytes32 topic1;
    bytes data;
}

struct Log2EventData {
    bytes32 topic1;
    bytes32 topic2;
    bytes data;
}

struct Log3EventData {
    bytes32 topic1;
    bytes32 topic2;
    bytes32 topic3;
    bytes data;
}

struct Log4EventData {
    bytes32 topic1;
    bytes32 topic2;
    bytes32 topic3;
    bytes32 topic4;
    bytes data;
}

abstract contract EventEmitter {
    function _allowedToEmitEvents() internal view virtual returns (bool) {
        return true;
    }

    function emitEventsLog1(Log1EventData[] calldata events) external {
        require(_allowedToEmitEvents());
        assembly {
            let eventsLength := events.length
            let dataOffset := add(events.offset, mul(0x20, eventsLength))

            for { let i := 0 } lt(i, eventsLength) { i := add(i, 1) } {
                let eventOffset := add(dataOffset, mul(i, 0x60))

                let topic1 := calldataload(eventOffset)

                let dataSize := calldataload(add(eventOffset, 0x40))

                let freeMemoryPointer := mload(0x40)

                calldatacopy(freeMemoryPointer, add(eventOffset, 0x60), dataSize)

                log1(freeMemoryPointer, dataSize, topic1)

                let remainder := mod(dataSize, 0x20)

                switch remainder
                case 0 { dataSize := mul(div(dataSize, 0x20), 0x20) }
                default { dataSize := mul(add(div(dataSize, 0x20), 1), 0x20) }

                dataOffset := add(dataOffset, dataSize)
            }
        }
    }

    function emitEventsLog2(Log2EventData[] calldata events) external {
        require(_allowedToEmitEvents());
        assembly {
            let eventsLength := events.length
            let dataOffset := add(events.offset, mul(0x20, eventsLength))

            for { let i := 0 } lt(i, eventsLength) { i := add(i, 1) } {
                let eventOffset := add(dataOffset, mul(i, 0x80))

                let topic1 := calldataload(eventOffset)
                let topic2 := calldataload(add(eventOffset, 0x20))

                let dataSize := calldataload(add(eventOffset, 0x60))

                let freeMemoryPointer := mload(0x40)

                calldatacopy(freeMemoryPointer, add(eventOffset, 0x80), dataSize)

                log2(freeMemoryPointer, dataSize, topic1, topic2)

                let remainder := mod(dataSize, 0x20)

                switch remainder
                case 0 { dataSize := mul(div(dataSize, 0x20), 0x20) }
                default { dataSize := mul(add(div(dataSize, 0x20), 1), 0x20) }

                dataOffset := add(dataOffset, dataSize)
            }
        }
    }

    function emitEventsLog3(Log3EventData[] calldata events) external {
        require(_allowedToEmitEvents());
        assembly {
            let eventsLength := events.length
            let dataOffset := add(events.offset, mul(0x20, eventsLength))

            for { let i := 0 } lt(i, eventsLength) { i := add(i, 1) } {
                let eventOffset := add(dataOffset, mul(i, 0xa0))

                let topic1 := calldataload(eventOffset)
                let topic2 := calldataload(add(eventOffset, 0x20))
                let topic3 := calldataload(add(eventOffset, 0x40))

                let dataSize := calldataload(add(eventOffset, 0x80))

                let freeMemoryPointer := mload(0x40)

                calldatacopy(freeMemoryPointer, add(eventOffset, 0xa0), dataSize)

                log3(freeMemoryPointer, dataSize, topic1, topic2, topic3)

                let remainder := mod(dataSize, 0x20)

                switch remainder
                case 0 { dataSize := mul(div(dataSize, 0x20), 0x20) }
                default { dataSize := mul(add(div(dataSize, 0x20), 1), 0x20) }

                dataOffset := add(dataOffset, dataSize)
            }
        }
    }

    function emitEventsLog4(Log4EventData[] calldata events) external {
        require(_allowedToEmitEvents());
        assembly {
            let eventsLength := events.length
            let dataOffset := add(events.offset, mul(0x20, eventsLength))

            for { let i := 0 } lt(i, eventsLength) { i := add(i, 1) } {
                let eventOffset := add(dataOffset, mul(i, 0xc0))

                let topic1 := calldataload(eventOffset)
                let topic2 := calldataload(add(eventOffset, 0x20))
                let topic3 := calldataload(add(eventOffset, 0x40))
                let topic4 := calldataload(add(eventOffset, 0x60))

                let dataSize := calldataload(add(eventOffset, 0xa0))

                let freeMemoryPointer := mload(0x40)

                calldatacopy(freeMemoryPointer, add(eventOffset, 0xc0), dataSize)

                log4(freeMemoryPointer, dataSize, topic1, topic2, topic3, topic4)

                let remainder := mod(dataSize, 0x20)

                switch remainder
                case 0 { dataSize := mul(div(dataSize, 0x20), 0x20) }
                default { dataSize := mul(add(div(dataSize, 0x20), 1), 0x20) }

                dataOffset := add(dataOffset, dataSize)
            }
        }
    }
}
