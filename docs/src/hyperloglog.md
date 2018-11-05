# HyperLogLog
_References: Original algorithm by Flajolet, Fusy, Gandouet & Meunier (DOI:10.1.1.76.4286) with some of the modifications by Heule, Nunkesser & Hall (DOI:10.1145/2452376.2452456)_

---

### Summary

An HLL is a very memory-efficient datastructure that keeps track of approximately how many distinct, hashable elements it's seen. A default HLL uses 16 KiB of memory and can return reliable estimates of up to some very large cardinality (on the order of 2^59 distinct elements).

This estimate of cardinality, has a median error of 0.5 %, and a 99 % chance of having an error less than 2.5 %, when the cardinality estimate is >1024. To accurately keep track of datasets smaller than 1024, use another datastructure like a `Set`.

This implementation is not optimally memory-efficient, but they are fast. More advanced tricks can be found in the Heule et al. paper linked above, which increases accuracy and lowers memory usage for small N.

The HLLs are not guaranteed to be threadsafe. To parallelize this implementation of HLL, each process/thread must operate on independent HLLs. These can then be efficiently merged using `union` or `union!` (or `∪`). This is much faster than using atomic operations.

### Usage

__Simple usage__

```
# Create an empty HLL with precision P (higher is more precise)
hll = HyperLogLog{P}()

# Create an empty HLL with precision 14 (default precision)
hll = HyperLogLog()

# Add a hashable elements to the HLL. This is fast if the hashing is fast.
push!(hll, "some element")

for i in 1:100000
  push!(hll, i)
end

# Get an estimate for the number of distinct elements in the HLL. Less fast.
length(hll) # will return something close to 100,000
```

__Documentation of all methods__

!!! note
    HyperLogLog supports the following operations, which have no HyperLogLog-specific docstring because they behave as stated in the documentation in Base:

```
Base.copy!
Base.copy
Base.sizeof # This one includes the underlying array
```

```@docs
Base.push!(x::HyperLogLog, val)
Base.length(x::HyperLogLog)
Base.isempty(x::HyperLogLog)
Base.empty!(x::HyperLogLog)
Base.union!(dest::HyperLogLog{P}, src::HyperLogLog{P}) where {P}
Base.union(x::HyperLogLog{P}, y::HyperLogLog{P}) where {P}
```
