# HyperLogLog
_References: Original algorithm: Flajolet, Fusy, Gandouet & Meunier: "Hyperloglog: The analysis of a near-optimal cardinality estimation algorithm".

With some of the modifications from: Heule, Nunkesser & Hall: "HyperLogLog in practice: Algorithmic engineering of a state of the art cardinality estimation algorithm"._

---

## What it is

An HyperLogLog is a very memory-efficient datastructure that keeps track of approximately how many distinct, hashable elements it's seen. A default HLL uses 16 KiB of memory and can return reliable estimates of up to some very large cardinality (on the order of 2^59 distinct elements).

This estimate of cardinality has a median error of 0.5 %, and a 99 % chance of having an error less than 2.5 %, when the cardinality estimate is >1024. To accurately keep track of datasets smaller than 1024, use another datastructure like a `Set`.

This implementation is not optimally memory-efficient, but it is fast. More advanced tricks can be found in the Heule et al. paper linked above, which increases accuracy and lowers memory usage for small N.

The HLLs are not guaranteed to be threadsafe. To parallelize this implementation of HLL, each process/thread must operate on independent HLLs. These can then be efficiently merged using `union` or `union!` (or `∪`). This is much faster than using atomic operations.

## Usage example

In this example, let's say I'm given 133 million [fastq-sequences](https://en.wikipedia.org/wiki/FASTQ_format) from a large sequencing project of Neanderthal bones. 133 million reads sounds like a lot, so, I'm worried that the lab folk went a little overboard on the PCR and the same reads are present in many copies. Hence, I want to know how many unique reads there are.
I don't care that the HyperLogLog doesn't fit in the cache, so I'll crank the `P` parameter up to 18 and spend the 256 KiB memory to maximize accuracy:

```
hll = HyperLogLog{18}()
reader = FASTQ.Reader(open("huge_file.fastq", "r"))
for record in reader
    seq = sequence(record) # we want a hashable DNA sequence    
    push!(hll, seq)
end
println("Number of distinct FASTQ-sequences: ", length(hll))
```  

## Interface

### Construction

The accuracy of a HLL depends on its `P` parameter. You can construct a HLL with its `P` parameter directly:

```
julia> hll = HyperLogLog{14}()
HyperLogLog{14}()
```

A P-value of 14 is considered default, so if you don't pass the parameter, 14 is assumed as default:

```
julia> HyperLogLog{14}() == HyperLogLog()
true
```

### Central functions

```@docs
Base.push!(x::HyperLogLog, val)
Base.length(x::HyperLogLog)
```

### Misc functions

!!! note
    HyperLogLog supports the following operations, which have no HyperLogLog-specific docstring because they behave as stated in the documentation in Base:

```
Base.copy!
Base.copy
Base.sizeof # This one includes the underlying array
```

```@docs
Base.isempty(x::HyperLogLog)
Base.empty!(x::HyperLogLog)
Base.union!(dest::HyperLogLog{P}, src::HyperLogLog{P}) where {P}
Base.union(x::HyperLogLog{P}, y::HyperLogLog{P}) where {P}
```
