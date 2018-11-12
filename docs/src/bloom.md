# Bloom filter
_Reference: Bloom: "Space/time trade-offs in hash coding with allowable errors"_

---

!!! note
    See also the page: [Cuckoo versus bloom filters](@ref)

## What it is

A bloom filter is the prototypical probabilistic data structure. Elements can be added to a bloom filter, and afterwards, the filter can be queried about whether or not an element is in the filter. A bloom filter exhibits false positives, but not false negatives. In other words, a bloom filter will sometimes report an object to be present when it in fact is not, but whenever the object is not found in the bloom filter, it is guaranteed to truly not be in the filter. Element cannot be extracted from a bloom filter.

A bloom filter is parameterized by two parameters, its length, `m` and the parameter `k`. Memory usage is `m/8` bytes plus a few bytes of overhead.

Bloom filters have infinite capacity, but their false positive rates asymptotically approach 1 as more objects are added. The capacity given for a bloom filter by this package refers to the number of distinct elements at which the expected false positive rate is below a given threshold.

### Querying (`in`)

Querying time is constant. A filter with parameters `m` and `k` containing `N` distinct object has an expected false positive rate of `(1-exp(-k*N/m))^k`.

### Pushing (`push!`)

Pushing time is constant and does not change the memory usage of the bloom filter. All hashable object can be pushed to the filter.

### Deletion

Bloom filters do not support deletion.

## Usage example

Let's use the same example as for the Cuckoo filter:
Again, I have a stream of [kmers](https://en.wikipedia.org/wiki/K-mer) that I want to count. Of course I use BioJulia, so these kmers are represented by a `DNAKmer{31}` object. I suspect my stream has up to 2 billion different kmers, so keeping a counting Dict would use up all my memory. However, most kmers are measurement errors that only appear once and that I do not need spend memory on keeping count of. So I keep track of which kmers I've seen using a Cuckoo filter. If I see a kmer more than once, I add it to the Dict.

```
params = constrain(BloomFilter, fpr=0.02, capacity=2_000_000_000)
if params.memory > 4e9 # I'm only comfortable using 4 GB of memory for this
    error("Too little memory :(")
end
filter = BloomFilter(params.m, params.k)
counts = Dict{Kmer, UInt8}() # Don't need to count higher than 255

for kmer in each(DNAKmer{31}, fastq_parser)
    if kmer in filter
        # Only add kmers we've seen before
        count = min(0xfe, get(counts, kmer, 0x01)) # No integer overflow
        counts[kmer] = count + 0x01
    else
        push!(filter, kmer)
    end
end
```

## Interface

### Construction

Bloom filters can be constructed directly given `m` and `k`:

`x = BloomFilter(100_000_000, k=10)`

And this will work just fine. However, in typical cases, people want to construct bloom filters with a set of constrains like "I have 100 MB memory and I want to hold object with a false positive rate of at most 5%". For this purpose, use the `constrain` function.

This function takes a type and two of three keyword arguments:
- `fpr`: Maximal false positive rate
- `memory`: Maximal memory usage
- `capacity`: Minimum number of distinct elements it can contain

It returns a `NamedTuple` with the parameters for an object of the specified type which fits the criteria:

```
julia> constrain(BloomFilter, fpr=0.05, memory=100_000_000)
(m = 799999808, k = 4, fpr = 0.04999999240568489, memory = 100000000, capacity = 128061884)
```

This means the optimal bloom filter consuming less than 100 MB of RAM and having a FPR of less than 0.05 can be constructed by:

`x = BloomFilter(799999808, 4)`

### Central functions

```@docs
Base.in(item, filter::BloomFilter)
Base.push!(filter::BloomFilter, item...)
```

### Misc functions

!!! note
    Bloom filters supports the following operations, which have no bloom-specific docstring because they behave as stated in the documentation in Base:

```
Base.copy!
Base.copy
Base.union!
Base.union
Base.sizeof # This one includes the underlying array
```

```@docs
Base.length(filter::BloomFilter)
Base.isempty(filter::BloomFilter)
Base.empty!(filter::BloomFilter)
constrain(::Type{BloomFilter}; fpr, memory, capacity)
```
