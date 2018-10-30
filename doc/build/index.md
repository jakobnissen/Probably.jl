
<a id='HyperLogLog.jl-1'></a>

# HyperLogLog.jl


Julia implementation of HyperLogLog with some accuracy improvements.


This is based on the original work by Flajolet, Fusy, Gandouet & Meunier (DOI:10.1.1.76.4286) with some of the modifications by Heule, Nunkesser & Hall (DOI:10.1145/2452376.2452456)


<a id='Summary-1'></a>

## Summary


An HLL is a very memory-efficient datastructure that keeps track of approximately how many distinct, hashable elements it's seen. A default HLL uses 16 KiB of memory and can return reliable estimates of up to about 2^62 distinct elements.


Note that the data structure is probabilistic. That means it'll return an *approximate* guess. When the guess is >1024, this guess has a median error of 0.5 %, and a 99 % chance of having an error less than 2.5 %. To accurately keep track of datasets smaller than 1024, use another datastructure like a `Set`.


This implementation is not optimally memory-efficient, but they are fast. More advanced tricks can be found in the Heule et al. paper linked above, which increases accuracy and lowers memory usage for small N.


The HLLs are not guaranteed to be threadsafe. To parallelize this implementation of HLL, each process/thread must operate on independent HLLs. These can then be efficiently merged using `union` or `union!` (or `∪`). This is much faster than using atomic operations.


<a id='How-to-use-1'></a>

## How to use

<a id='HyperLogLog.HLL' href='#HyperLogLog.HLL'>#</a>
**`HyperLogLog.HLL`** &mdash; *Type*.



```
HLL{P}()
```

Construct a HyperLogLog cardinality counter. Hashable values can be added to the counter, and an approximate count of distinct elements (cardinality) retrieved. The counter has an error of < 2.5% w. 99% probability and median error of 0.5%, but is only accurate for 2^10 < cardinality < 2^62.

An HLL{P} consumes 2^P bytes of memory. I recommend P = 14 (using 16 KiB).

**Examples**

```
julia> hll = HLL{14}();

julia> for i in 1:1<<28 push!(hll, i) end

julia> length(hll)
271035100

julia> empty!(hll);
```


<a target='_blank' href='https://github.com/jakobnissen/HyperLogLog.jl/blob/b4e3e276111cf4554c392c3d7d4c2be96a36f492/src/HyperLogLog.jl#L20-L41' class='documenter-source'>source</a><br>

<a id='Base.union!-Union{Tuple{P}, Tuple{HLL{P},HLL{P}}} where P' href='#Base.union!-Union{Tuple{P}, Tuple{HLL{P},HLL{P}}} where P'>#</a>
**`Base.union!`** &mdash; *Method*.



```
union!(dest::HLL{P}, src::HLL{P})
```

Overwrite `dest` with the same result as `union(dest, src)`, returning `dest`.

**Examples**

```
julia> # length(c) ≥ length(b) is not guaranteed, but overwhelmingly likely
julia> c = union!(a, b); c === a && length(c) ≥ length(b)
true
```


<a target='_blank' href='https://github.com/jakobnissen/HyperLogLog.jl/blob/b4e3e276111cf4554c392c3d7d4c2be96a36f492/src/HyperLogLog.jl#L60-L71' class='documenter-source'>source</a><br>


<a id='How-it-works-1'></a>

## How it works


Add some stuff here


<a id='Index-1'></a>

## Index

- [`HyperLogLog.HLL`](index.md#HyperLogLog.HLL)
- [`Base.union!`](index.md#Base.union!-Union{Tuple{P}, Tuple{HLL{P},HLL{P}}} where P)
