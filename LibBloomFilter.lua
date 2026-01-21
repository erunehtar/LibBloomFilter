-- MIT License
--
-- Copyright (c) 2026 Erunehtar
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
--
--
-- Bloom Filter implementation for WoW Lua 5.1 environment.
-- Based on: https://en.wikipedia.org/wiki/Bloom_filter.
--
-- Credits:
--   The Bloom Filter was invented by Burton Howard Bloom in 1970.
--   B. H. Bloom, "Space/time trade-offs in hash coding with allowable errors,"
--   Communications of the ACM, vol. 13, no. 7, pp. 422-426, 1970.
--
-- Optimized for 32-bit Lua environment with multiple hash functions.
-- Uses FNV-1a hash function with different seeds for multiple hashes.
-- Compact bit array representation using 32-bit integers.
-- Supports insertion, membership testing, clear, export/import, and false positive rate estimation.

local MAJOR, MINOR = "LibBloomFilter", 1
assert(LibStub, MAJOR .. " requires LibStub")

local LibBloomFilter = LibStub:NewLibrary(MAJOR, MINOR)
if not LibBloomFilter then return end -- no upgrade needed

-- Local lua references
local assert, type, setmetatable, pairs, ipairs = assert, type, setmetatable, pairs, ipairs
local band, bor, bxor, lshift, rshift = bit.band, bit.bor, bit.bxor, bit.lshift, bit.rshift
local floor, ceil, log, exp, random = math.floor, math.ceil, math.log, math.exp, fastrandom
local tostring, tonumber, strbyte = tostring, tonumber, strbyte
local tinsert = table.insert

--- Hash a value using FNV-1a with different seeds.
--- @param value any Value to hash.
--- @param seed number Seed for hash variation.
--- @return number hash 32-bit hash value.
local function Hash(value, seed)
    local str = tostring(value)
    local h = 2166136261 + seed
    for i = 1, #str do
        h = bxor(h, strbyte(str, i))
        h = (h * 16777619) % 4294967296
    end
    return h
end

--- Set a bit in the filter.
--- @param bitIndex number Bit index to set.
local function SetBit(self, bitIndex)
    local intIndex = floor(bitIndex / 32) + 1
    local bitOffset = bitIndex % 32
    self.bits[intIndex] = bor(self.bits[intIndex], lshift(1, bitOffset))
end

--- Check if a bit is set in the filter.
--- @param bitIndex number Bit index to check.
--- @return boolean
local function GetBit(self, bitIndex)
    local intIndex = floor(bitIndex / 32) + 1
    local bitOffset = bitIndex % 32
    return band(self.bits[intIndex], lshift(1, bitOffset)) ~= 0
end

--- @class LibBloomFilter Bloom Filter data structure.
--- @field New fun(capacity: number, falsePositiveRate?: number): LibBloomFilter
--- @field Insert fun(self: LibBloomFilter, value: any)
--- @field Contains fun(self: LibBloomFilter, value: any): boolean
--- @field Clear fun(self: LibBloomFilter)
--- @field Export fun(self: LibBloomFilter): LibBloomFilterState
--- @field Import fun(state: LibBloomFilterState): LibBloomFilter
--- @field EstimateFalsePositiveRate fun(self: LibBloomFilter): number
--- @field numBits number Total number of bits in the filter.
--- @field numHashes number Number of hash functions.
--- @field bits [number] Bit array represented as array of 32-bit integers.
--- @field itemCount number Number of items inserted.

--- @class LibBloomFilterState Compact representation of a Bloom Filter state.
--- @field [1] number Total number of bits in the filter.
--- @field [2] number Number of hash functions.
--- @field [3] number Number of items inserted.
--- @field [4] number[] Bit array represented as array of 32-bit integers.

LibBloomFilter.__index = LibBloomFilter

--- Create a new Bloom Filter instance.
--- @param capacity number Capacity of the filter (expected number of values).
--- @param falsePositiveRate number Desired false positive rate (between 0 and 1, default: 0.01 which means 1%).
--- @return LibBloomFilter instance The new Bloom Filter instance.
function LibBloomFilter.New(capacity, falsePositiveRate)
    assert(capacity and capacity > 0, "capacity must be greater than 0")
    falsePositiveRate = falsePositiveRate or 0.01
    assert(falsePositiveRate > 0 and falsePositiveRate < 1, "falsePositiveRate must be between 0 and 1")

    -- Calculate optimal bit array size: m = -n*ln(p) / (ln(2)^2)
    local bitsPerItem = -log(falsePositiveRate) / (log(2) ^ 2)
    local numBits = ceil(capacity * bitsPerItem)

    -- Calculate optimal number of hash functions: k = (m/n) * ln(2)
    local numHashes = ceil((numBits / capacity) * log(2))

    -- Create bit array (using 32-bit integers)
    local numInts = ceil(numBits / 32)
    local bits = {}
    for i = 1, numInts do
        bits[i] = 0
    end

    return setmetatable({
        numBits = numBits,
        numHashes = numHashes,
        itemCount = 0,
        bits = bits,
    }, LibBloomFilter)
end

--- Insert a value into filter.
--- @param value any Value to insert.
function LibBloomFilter:Insert(value)
    assert(value ~= nil, "value cannot be nil")
    for i = 0, self.numHashes - 1 do
        local h = Hash(value, i)
        local bitIndex = h % self.numBits
        SetBit(self, bitIndex)
    end
    self.itemCount = self.itemCount + 1
end

--- Determine if a value is possibly in the filter.
--- @param value any Value to check.
--- @return boolean contains True if value might be in the set, false if definitely not.
function LibBloomFilter:Contains(value)
    assert(value ~= nil, "value cannot be nil")
    local n = self.numHashes - 1
    for i = 0, n do
        local h = Hash(value, i)
        local bitIndex = h % self.numBits
        if not GetBit(self, bitIndex) then
            return false
        end
    end
    return true
end

--- Clear all values from the filter.
function LibBloomFilter:Clear()
    local numInts = ceil(self.numBits / 32)
    for i = 1, numInts do
        self.bits[i] = 0
    end
    self.itemCount = 0
end

--- Export the current state of the filter.
--- @return LibBloomFilterState state Compact representation of the filter.
function LibBloomFilter:Export()
    return {
        self.numBits,
        self.numHashes,
        self.itemCount,
        self.bits,
    }
end

--- Import a new Bloom Filter from a compact representation.
--- @param state LibBloomFilterState Compact representation of the filter.
--- @return LibBloomFilter instance The imported Bloom Filter instance.
function LibBloomFilter.Import(state)
    assert(state and type(state) == "table", "state must be a table")
    assert(state[1] and state[1] > 0, "invalid numBits in state")
    assert(state[2] and state[2] > 0, "invalid numHashes in state")
    assert(state[3] and state[3] >= 0, "invalid itemCount in state")
    assert(state[4] and type(state[4]) == "table", "invalid bits array in state")
    return setmetatable({
        numBits = state[1],
        numHashes = state[2],
        itemCount = state[3],
        bits = state[4],
    }, LibBloomFilter)
end

--- Estimate the current false positive rate (FPR) of the filter based on current load factor.
--- @return number fpr Estimated false positive rate.
function LibBloomFilter:EstimateFalsePositiveRate()
    -- FPR ≈ (1-e^(-kn/m))^k
    -- Where:
    --   k = number of hash functions
    --   m = number of bits in the filter
    --   n = number of inserted items
    --   e = Euler's number (approx. 2.71828)
    local k = self.numHashes
    local m = self.numBits
    local n = self.itemCount
    return (1 - exp(-(k * n) / m)) ^ k
end

-------------------------------------------------------------------------------
-- TESTS: Verify Bloom Filter correctness
-------------------------------------------------------------------------------

--[[ -- Uncomment to run tests when loading this file

local function RunLibBloomFilterTests()
    print("=== LibBloomFilter Tests ===")

    -- Test 1: Basic insertion and membership
    local bf = LibBloomFilter.New(100, 0.01)
    assert(not bf:Contains("item1"), "Test 1 Failed: Empty filter should not contain items")

    bf:Insert("item1")
    bf:Insert("item2")
    bf:Insert("item3")
    assert(bf:Contains("item1"), "Test 1 Failed: Should contain inserted item1")
    assert(bf:Contains("item2"), "Test 1 Failed: Should contain inserted item2")
    assert(bf:Contains("item3"), "Test 1 Failed: Should contain inserted item3")
    print("Test 1 PASSED: Basic insertion and membership")

    -- Test 2: False positives vs true negatives
    local testBf = LibBloomFilter.New(100000, 0.01)
    for i = 1, 50000 do
        local item = "test_" .. i
        testBf:Insert(item)
    end

    local falsePositives = 0
    local testCount = 100000
    for i = 50001, 50000 + testCount do
        local item = "test_" .. i
        if testBf:Contains(item) then
            falsePositives = falsePositives + 1
        end
    end

    local actualFPR = falsePositives / testCount
    local estimatedFPR = testBf:EstimateFalsePositiveRate()
    print(string.format("Test 2 PASSED: FP Rate - Actual: %.4f, Estimated: %.4f", actualFPR, estimatedFPR))
    assert(actualFPR < 0.05, "Test 2 Failed: False positive rate too high")

    -- Test 3: Export and Import
    local bf3 = LibBloomFilter.New(100, 0.01)
    for i = 1, 100 do
        bf3:Insert("export" .. i)
    end

    local exported = bf3:Export()
    local imported = LibBloomFilter.Import(exported)

    for i = 1, 100 do
        assert(imported:Contains("export" .. i), "Test 3 Failed: Imported filter should contain export" .. i)
    end
    print("Test 3 PASSED: Export and Import")

    -- Test 4: Clear functionality
    local bf4 = LibBloomFilter.New(100, 0.01)
    bf4:Insert("clear1")
    bf4:Insert("clear2")
    assert(bf4:Contains("clear1"), "Test 4 Failed: Should contain clear1 before clear")

    bf4:Clear()
    assert(not bf4:Contains("clear1"), "Test 4 Failed: Should not contain clear1 after clear")
    assert(not bf4:Contains("clear2"), "Test 4 Failed: Should not contain clear2 after clear")
    print("Test 4 PASSED: Clear functionality")

    -- Test 5: No false negatives (critical property)
    local bf5 = LibBloomFilter.New(100000, 0.01)
    local items = {}
    for i = 1, 100000 do
        items[i] = "item_" .. i
        bf5:Insert(items[i])
    end

    for i = 1, 100000 do
        assert(bf5:Contains(items[i]), "Test 5 Failed: False negative detected for " .. items[i])
    end
    print("Test 5 PASSED: No false negatives")

    print("=== All LibBloomFilter Tests PASSED ===\n")
end

RunLibBloomFilterTests()

]] --
