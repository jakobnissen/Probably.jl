Add performance graphs of Cuckoo and Bloom (insertion, fetching).

__Potential future improvement__

Encode the cells of HyperLogLog? This will decrease memory consumption by ~25%, but will decrease speed a little. Right now, I think the memory requirement of HLLs is so low, people would prefer more speed than to save 4 KB of RAM per instance.
