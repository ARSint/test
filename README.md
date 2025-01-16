Hash Table Algorithm for Address Filtering
Address Mapping:

Any 48-bit address (e.g., the destination MAC address) is input to a hash function.
The result of this hash function is a value between 0 and 63, corresponding to one of 64 hash table entries.
Hash Table Registers:

The 64-bit hash table is implemented using two 32-bit registers:
HASH0 (lower 32 bits).
HASH1 (upper 32 bits).
Together, HASH0 and HASH1 form a single 64-bit hash table.
Frame Acceptance Criteria:

The Ethernet controller uses the hash function result to index into the hash table.
If the corresponding bit in the hash table (i.e., in HASH0 or HASH1) is set to 1, the frame is accepted.
If the bit is 0, the frame is rejected.
Key Steps:
Hash Function Computation:

Compute a hash value (e.g., using a CRC or XOR-based algorithm) from the 48-bit destination address.
The hash function reduces the 48-bit address to a 6-bit index.
Index Mapping:

The 6-bit hash result determines the bit position in the hash table:
If the hash result is N (0–63):
If N < 32, the bit is in HASH0.
If N ≥ 32, the bit is in HASH1.
Check Bit Status:

Check the bit at position N in the hash table:
If 1: Frame is accepted.
If 0: Frame is discarded.
