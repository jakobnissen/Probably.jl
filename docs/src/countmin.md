# Count-min sketch

## What it is

A count-min sketch is a probabilistic counter of hashable objects. Similar to bloom filters in structure, they exhibit false positives (may overcount), but no false negatives (never undercounts).
Count-min sketches have two parameters: Length and width. Its accuracy is described by two numbers: ϵ describing its error and δ describing its probability of error. More rigorously, if N is the true count of an event, E is the estimate given by a sketch and T the total count of items in the sketch, E ≤ N + Tϵ with probability (1 - δ).
The parameters of a sketch can be determined by `length = 2/ϵ` and `depth = -log(δ)/log(2)`.

## Adding (`add!`)

Count-min sketches has infinite capacity, but adding elements steadily increases the probability of a miscounting other values. Add time is proportional to `depth`.

## Querying (`getindex`)

Querying time is proportional to `depth`. It has a certain risk of reporting too high counts, but no risk of undercounting.

## Subtracting/deletion.

Count-min sketches do not support subtracting or deleting.

## Usage example

I don't know anything about astronomy, but indulge me: Say I want to count how many times different stars have been observed. Sightings are available in a public database. There's about 1.4 billion known stars, with about 5 billion sightings. I have 10 GB of available RAM to balance `ϵ` and `δ`.

First, I decide that a UInt8 (maximum count of 255) is fine - I don't care that Polaris have been observed 100,000 times.

Most stars have a low count, so I really care about miscounts not being too large, and I care less about them being frequent or infrequent, so I should minimize `ϵ` rahter than `δ`, which means maximizing length rather than depth. So if I pick width = 4 and length = 2.5e9. This means the probability of miscounting with `4*2/10e4 * 5e9 = 4` with a probability of `exp(-4*log(2)) 6.25%`:

```
sketch = CountMinSketch(2.5e9, 4)

for star in catalogue
    push!(sketch, star) # same as adding one using add!
end

# How many times have a particular star observed?
println(sketch["HD 143183"])
```

## Interface

### Construction

At the moment, count-min sketches can *only* be constructed from the parameters `length` and `width`:

`sketch = CountMinSketch{UInt8}(10000, 5)`

Although the default eltype of count-min sketches are `UInt8`, so you can avoid specifying that:

`sketch = CountMinSketch(10000, 5)`

### Central functions

```@docs
Base.getindex(sketch::CountMinSketch, index)
add!(sketch::CountMinSketch, item, count)
Base.push!(sketch::CountMinSketch, item)
```

### Misc functions

!!! note
    Count-min sketches support the following operations, which have no specific docstring because they behave as stated in the documentation in Base:

```
Base.eltype
Base.copy!
Base.copy
Base.sizeof # This one includes the underlying array
```

```@docs
Base.:+(x::CountMinSketch{T}, y::CountMinSketch{T}) where {T}
fprof(sketch::CountMinSketch)
Base.haskey(sketch::CountMinSketch, key)
Base.empty!(sketch::CountMinSketch)
Base.isempty(sketch::CountMinSketch)
```
