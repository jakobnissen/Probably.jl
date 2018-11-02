# Cuckoo filter
_Reference: Fan, Andersen, Kaminsky & Mitzenmacher: "Cuckoo Filter: Practically Better Than Bloom"_

__Note: See also the page: "Cuckoo versus Bloom filters"__

## What it is
A cuckoo filter is conceptually similar to a bloom filter, even though the underlying algorithm is quite different.

The cuckoo filter is similar to a `Set`. Hashable objects can be pushed into the filter, but objects cannot be extracted from the filter. Querying the filter, i.e. asking whether an object is in a filter is fast, but cuckoo filters has a certain probability of falsely returning `true` when querying about an object not actually in the filter. When querying an object that is in the filter, it is guaranteed to return `true`.

A cuckoo filter is defined by two parameters, `F` and its length `L`. Memory usage is proportional to `F*L`, and the false positive rate is approximately proportional to `N/(2^F*L)` where N is the number of elements in the filter.

### Querying

Querying time is constant for all values of N, `F` and `L`. When querying about an object in the filter, it is guaranteed to return `true`. Querying about objects not in the filter returns `true` with a probability proportional to `N/(2^F*L)`.

In general, two distinct objects A and B will have a `1/(2^F-1)` chance of sharing so-called "fingerprints". Independently, each object is assigned two "buckets" in the range 1:L/4, and inserted in an arbitrary of the two buckets. If objects A and B share fingerprints, and object A is in one of B's buckets, the existence of A will make a query for B return `true`, even when it's not in the filter.

### Pushing

Only hashable objects can be inserted into the filter. Inserting time is stochastic, but its expected duration is proportional to `1/(1 - N/L)`. To avoid infinite insertion times as N approaches `L`, an insert operation may fail if the filter is too full. A failed push operation returns `false`.

Pushing may yield false positives: If an object A exists in the filter, and querying for object B would falsely return `true`, then pushing B to the filter has a probability `1/2 + 1/2 * N/L` of returning `true` while doing nothing, because B is falsely believed to already be in the filter.

### Deletion

Objects can be deleted from the filter. Deleting operation also exhibits false positives: If B has been pushed to the filter, falsely returning success, then deleting A will also delete B.

Deletion of objects is fast and constant time, except if the filter is at full capacity. In that case, it will attempt to self-organize after a deletion to allow new objects to be pushed. This might take up to 200 microseconds.

### `FastCuckoo` and `SmallCuckoo`

Probably.jl comes with two different implementations of the cuckoo filter: `FastCuckoo` and `SmallCuckoo`. The latter uses a more complicated encoding scheme to achieve a slightly smaller memory footprint, but which also make all operations slower. The following plot shows how the speed of pushing objects depend on the load factor, i.e. how full the filter is, and how `FastCuckoo`s are ~2.5x faster than `SmallCuckoo`s, but that the `SmallCuckoo` uses about 10% less memory. FastCuckoo is displayed in blue, SmallCuckoo in orange.

![](cuckooperformance.png)

## Interface

### Construction

A cuckoo filter can be constructed directly from the two parameters `F` and `L`, where L is the number of fingerprint slots in the fingerprint. Remember that `L` should be a power-of-two:

`julia> FastCuckoo{12}(2^32) # F=12, L=2^32, about 6 GiB in size`

However, typically, one wants to construct cuckoo filters under some kind of constrains: Perhaps I need to store at least 1.1 billion distinct elements, with a maximal false positive rate of 0.004. For this purpose, use the `constrain` function.

This function takes a type and two of three keyword arguments:
- `fpr`: Maximal false positive rate
- `memory`: Maximal memory usage
- `capacity`: Minimum number of distinct elements it can contain

It returns a `NamedTuple` with the parameters for an object of the specified type which fits the criteria:

```
julia> constrain(SmallCuckoo, fpr=0.004, capacity=1.1e9)
(F = 11, nfingerprints = 2147483648, fpr = 0.002196371220581028, memory = 2952790074, capacity = 2040109466)
```

Having passed false positive rate and capacity, the function determined the smallest possible `SmallCuckoo` that fits these criteria. We can see from the fields `F` and `nfingerprints` that such a `SmallCuckoo` can be constructed with:

`SmallCuckoo{11}(2147483648)`

Furthermore, we can also see that those particular constrains were quite unlucky: The actual false positive rate of this filter will be ~0.0022 (at full capacity), and its actual capacity will be ~2 billion elements. It is not possible to create a smaller `SmallCuckoo` which fits the given criteria.

### Central functions

```@docs
Base.in(item, filter::AbstractCuckooFilter)
Base.push!(filter::AbstractCuckooFilter, item)
Base.delete!(filter::AbstractCuckooFilter, item)
```

### Misc operations

```@docs
Base.isempty(filter::AbstractCuckooFilter)
Base.empty!(filter::AbstractCuckooFilter)
Base.union!(filter::AbstractCuckooFilter)
Base.union(filter::AbstractCuckooFilter)
Base.copy!(dst::AbstractCuckooFilter, src::AbstractCuckooFilter)
Base.copy(filter::AbstractCuckooFilter)
loadfactor(filter::AbstractCuckooFilter)
fprof
capacityof
constrain
```
