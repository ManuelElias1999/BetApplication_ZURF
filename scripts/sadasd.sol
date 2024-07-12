// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Calculator {
    uint constant MAX_RESULT = 1000;
    address public owner;

    constructor() {
        owner = msg.sender; // El creador del contrato es el owner inicialmente
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _; // Continuar con la ejecución de la función si el require pasa
    }

    function add(uint a, uint b) public onlyOwner view returns (uint) {
        uint result = a + b;

        // Verifica que el resultado no exceda el límite máximo usando assert
        assert(result <= MAX_RESULT);

        return result;
    }
}
