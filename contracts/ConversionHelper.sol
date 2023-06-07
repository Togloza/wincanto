// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

contract ConversionHelper {
    // Helper function to convert addresses to strings
    function addressToString(address _address) public pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(_address)));
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(42);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint256(uint8(value[i + 12] >> 4))];
            str[3 + i * 2] = alphabet[uint256(uint8(value[i + 12] & 0x0f))];
        }

        return string(str);
    }

    // Helper function to convert uint256 to string
    function uint256ToString(uint256 _value) public pure returns (string memory) {
        if (_value == 0) {
            return "0";
        }

        uint256 length;
        uint256 temp = _value;
        while (temp != 0) {
            length++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(length);
        while (_value != 0) {
            length -= 1;
            buffer[length] = bytes1(uint8(48 + (_value % 10)));
            _value /= 10;
        }

        return string(buffer);
    }

    // Helper function to convert bool to string
    function boolToString(bool _value) public pure returns (string memory) {
        return _value ? "true" : "false";
    }

    function hexToDecimal(string memory hexString) public pure returns (uint256) {
        uint256 decimalValue = 0;
        uint256 digitValue;
        
        for (uint256 i = 0; i < bytes(hexString).length; i++) {
            uint8 charCode = uint8(bytes(hexString)[i]);
            
            if (charCode >= 48 && charCode <= 57) {
                digitValue = charCode - 48;
            } else if (charCode >= 65 && charCode <= 70) {
                digitValue = charCode - 55;
            } else if (charCode >= 97 && charCode <= 102) {
                digitValue = charCode - 87;
            } else {
                revert("Invalid hex string");
            }
            
            decimalValue = decimalValue * 16 + digitValue;
        }
        
        return decimalValue;
    }
}
