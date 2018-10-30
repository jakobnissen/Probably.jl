# HyperLogLog.jl
Julia implementation of HyperLogLog with some accuracy improvements.

This is based on the original work by Flajolet, Fusy, Gandouet & Meunier (DOI:10.1.1.76.4286)
with some of the modifications by Heule, Nunkesser & Hall (DOI:10.1145/2452376.2452456)

### Summary

An HLL is a very memory-efficient datastructure that keeps track of approximately
how many distinct, hashable elements it's seen. A default HLL uses 16 KiB of memory and
can return reliable estimates of up to about 2^62 distinct elements.

Note that the data structure is probabilistic. That means it'll return an *approximate*
guess. When the guess is >1024, this guess has a median error of 0.5 %, and a 99 %
chance of having an error less than 2.5 %. To accurately keep track of datasets smaller
than 1024, use another datastructure like a `Set`.

This implementation is not optimally memory-efficient, but they are fast. More advanced
tricks can be found in the Heule et al. paper linked above, which increases accuracy and
lowers memory usage for small N.

The HLLs are not guaranteed to be threadsafe. To parallelize this implementation of HLL, each process/thread must operate on independent HLLs. These can then be efficiently merged using `union` or `union!` (or `∪`). This is much faster than using atomic operations.

### Usage

__Simple usage__

```
# Create an empty HLL with precision P (higher is more precise)
hll = HLL{P}()

# Create an empty HLL with precision 14 (default precision)
hll = HLL()

# Add a hashable elements to the HLL. This is fast if the hashing is fast.
push!(hll, "some element")

for i in 1:100000
  push!(hll, i)
end

# Get an estimate for the number of distinct elements in the HLL. Less fast.
length(hll) # will return something close to 100,000
```

__Documentation of all methods__

`push!(x::HLL, val)`

Adds `val` to the HLL, returning the HLL.

---
`length(x::HLL)`

Return an estimate of the number of distinct elements pushed to the HLL.
For P = 14, `length(x::HLL{P})` is accurate to within 2.5% with 99% probability
if the number is between 2^10 and ~2^62. Median error is ~0.5% in this range.

---
`empty!(x::HLL)`

Reset the HLL to its empty (beginning) state, returning it.

---
`isempty(x::HLL)`

returns `true` if the HLL has not seen any elements, `false` otherwise.
This is guaranteed to be correct, and so can be `true` even when length(x) > 0.

---
`union(x::HLL{P}, y::HLL{P}) where {P}`, also accessible using `x ∪ y`

Create a new HLL identical to an HLL which has seen the union of the elements
`x` and `y` has seen.

---
`union!(dest::HLL{P}, src::HLL{P}) where {P}`

Overwrite `dest` with the same result as `union(dest, src)`, returning `dest`.


---
`copy(x::HLL)`

Create a new copy of `x`, returning it.

---
`copy!(dest::HLL{P}, src::HLL{P}) where {P}`

Overwrite `dest` with the same result as `copy(src)`, returning `dest`.

---
`sizeof(x::HLL)`

Number of bytes the HLL consumes of memory. Equal to 2^P.

---
`Base.(==)(x::HLL, y::HLL)`

`x == y` returns `true` if the parameter P for `x` and `y` is the same, and
they contain the same data. This does not mean they have seen the same
elements, but that `x` and `y` behave identically.
