# Bloom filter
_Reference: Bloom: "Space/time trade-offs in hash coding with allowable errors"_

__Note: See also the page: "Cuckoo versus Bloom filters"__

## What it is

A bloom filter is the prototypical probabilistic data structure. Elements can be added to a bloom filter, and afterwards, the filter can be queried about whether or not an element is in the filter. A bloom filter exhibits false positives, but not false negatives. In other words, a bloom filter will sometimes report an object to be present when it in fact is not, but whenever the object is not found in the bloom filter, it is guaranteed to truly not be in the filter. Element cannot be extracted from a bloom filter.

A bloom filter is parameterized by two parameters, its length, `m` and the parameter `k`. Memory usage is `m/8` bytes plus a few bytes of overhead.

Bloom filters have infinite capacity, but their false positive rates asymptotically approach 1 as more objects are added. The capacity given for a bloom filter by this package refers to the number of distinct elements at which the expected false positive rate is below a given threshold.

### Pushing

Pushing time is constant and does not change the memory usage of the bloom filter. All hashable object can be pushed to the filter.

### Querying

Querying time is constant. A filter with parameters `m` and `k` containing `N` distinct object has an expected false positive rate of `(1-exp(-k*N/m))^k`.

### Deletion

Bloom filters do not support deletion.

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

*Note: Cuckoo filters supports the following operations, which have no cuckoo-specific docstring because they behave as stated in the documentation in Base:*
```
Base.copy!
Base.copy
Base.sizeof # This one includes the underlying array
```

```@docs
Base.isempty(filter::BloomFilter)
Base.empty!(filter::BloomFilter)
Base.union!
Base.union
constrain(::Type{BloomFilter}; fpr, memory, capacity)
```
