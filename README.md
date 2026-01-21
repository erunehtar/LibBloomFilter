# LibBloomFilter

Bloom Filter for WoW Lua 5.1 environment - Probabilistic set membership testing with minimal memory footprint.

## Features

- Efficiently tests whether an element is a member of a set.
- Low memory usage, suitable for constrained environments.
- Simple API for adding and checking elements.
- Configurable false positive rate.
- Compatible with World of Warcraft Lua 5.1 environment.

## Installation

To install LibBloomFilter, simply download the `LibBloomFilter.lua` file and include it in your WoW addon folder. Then, you can load it using LibStub in your addon code.

```lua
local LibBloomFilter = LibStub("LibBloomFilter")
```

## Usage

```lua
-- Create a new Bloom Filter with expected 1000 values and 1% false positive rate
local filter = LibBloomFilter.New(1000, 0.01)

-- Add values to the filter
for i = 1, 1000 do
    filter:Insert("value" .. i)
end

-- Check for membership
for i = 1, 1200 do
    local value = "value" .. i
    if filter:Contains(value) then
        print(value .. " is possibly in the set.")
    else
        print(value .. " is definitely not in the set.")
    end
end

-- Export the filter state, so you can serialize it
local state = filter:Export()

-- Import the filter state into a new filter
local newFilter = LibBloomFilter.Import(state)
```

## API

### LibBloomFilter.New(capacity, falsePositiveRate)

Creates a new Bloom Filter instance.

- `capacity`: Capacity of the Bloom Filter (expected number of values).
- `falsePositiveRate`: The desired false positive rate (between 0 and 1, default: 0.01 which means 1%).
- Returns: A new Bloom Filter instance.

### filter:Insert(value)

Insert a value into the Bloom Filter.

- `value`: The value to insert (any).

### filter:Contains(value)

Determine if a value is possibly in the Bloom Filter.

- `value`: The value to check (any).
- Returns: `true` if the value is possibly in the set, `false` if definitely not.

### filter:Export()

Export the current state of the Bloom Filter.

- Returns: A compact representation of the Bloom Filter state.

### LibBloomFilter.Import(state)

Import the Bloom Filter state from a compact representation.

- `state`: A compact representation of the Bloom Filter state.
- Returns: A new Bloom Filter instance.

### filter:Clear()

Clear all values from the Bloom Filter.

### filter:GetFalsePositiveRate()

Estimate the current false positive rate of the patterned bloom filter.

- Returns: Estimated false positive rate (number).

## License

This library is released under the MIT License. See the LICENSE file for details.
