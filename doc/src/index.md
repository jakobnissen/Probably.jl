# HyperLogLog.jl

Julia implementation of HyperLogLog with some accuracy improvements.

This is based on the original work by Flajolet, Fusy, Gandouet & Meunier (DOI:10.1.1.76.4286)
with some of the modifications by Heule, Nunkesser & Hall (DOI:10.1145/2452376.2452456)

## Summary

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

## How to use

```@docs
HLL{P}
union!(dest::HLL{P}, src::HLL{P}) where {P}
```

## How it works

Add some stuff here

## Index

```@index
```
