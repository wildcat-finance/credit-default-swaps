# Test analysis

`test/Scaffold.t.sol` deploys the marker, imports the pinned Wildcat `MarketState` type, assigns the
90-day value to its `timeDelinquent` member and checks both marker constants. The CI profile passed
1/1 tests. Coverage reports 0/0 statements because the source has constants but no executable
function body.

Fizz entry-point discovery has no mutable function from which to build a stateful handler. A generated
Medusa or Echidna suite would assert bytecode constants without exercising a transition. The round
therefore records the Fizz applicability result and defers stateful campaign generation to Step 2,
where the facility adds value-moving entry points.
