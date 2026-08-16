# Entry points

## Grep-verified mutating entry points

None. `src/Scaffold.sol` contains no function declaration. Solidity generates view accessors for the
two public constants; view functions are excluded from the mutating entry-point set.

## Value flows

None. The contract cannot receive Ether and does not call or transfer tokens.

## State transitions

None. Both values are embedded in deployed bytecode.
