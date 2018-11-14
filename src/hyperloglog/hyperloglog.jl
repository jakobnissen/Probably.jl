# From Flajolet, Philippe; Fusy, Éric; Gandouet, Olivier; Meunier, Frédéric (2007)
# DOI: 10.1.1.76.4286
# With algorithm improvements by Google (https://ai.google/research/pubs/pub40671)

# Principle:
# When observing N distinct uniformly distributed integers, the expected maximal
# number of leading zeros in the integers is log(2, N), with large variation.
# To cut variation, we keep 2^P counters, each keeping track of N/2^P
# observations. The estimated N for each counter is averaged using harmonic mean.
# Last, corrections for systematic bias are added, one multiplicative and one
# additive factor.
# To make the observations uniformly distributed integers, we hash them.

include("constants.jl")

"""
    HyperLogLog{P}()

Construct a HyperLogLog cardinality counter. Hashable values can be added to the
counter, and an approximate count of distinct elements (cardinality) retrieved.
The counter has an error of < 2.5% w. 99% probability and median error of 0.5%,
but is only accurate for 2^10 < cardinality < 2^62.

An HyperLogLog{P} consumes 2^P bytes of memory. I recommend P = 14 (using 16 KiB).

# Examples
```
julia> hll = HyperLogLog{14}();

julia> for i in 1:1<<28 push!(hll, i) end

julia> length(hll)
271035100

julia> empty!(hll);
```
"""
struct HyperLogLog{P}
    counts::Vector{UInt8}

    function HyperLogLog{P}() where {P}
        isa(P, Integer) || throw(ArgumentError("P must be integer"))
        (P < 4 || P > 18) && throw(ArgumentError("P must be between 4 and 18"))
        return new(zeros(UInt8, sizeof(HyperLogLog{P})))
    end
end

HyperLogLog() = HyperLogLog{14}() # This is a good value for most practical applications

Base.show(io::IO, x::HyperLogLog{P}) where {P} = print(io, "HyperLogLog{$(P)}()")

# Strangely, 2^P compiles less effectively that 1<<P here.
Base.sizeof(::Type{HyperLogLog{P}}) where {P} = 1 << P
Base.sizeof(x::HyperLogLog{P}) where {P} = sizeof(typeof(x))

"""
    union!(dest::HyperLogLog{P}, src::HyperLogLog{P})

Overwrite `dest` with the same result as `union(dest, src)`, returning `dest`.

# Examples
```
julia> # length(c) ≥ length(b) is not guaranteed, but overwhelmingly likely
julia> c = union!(a, b); c === a && length(c) ≥ length(b)
true
```
"""
function Base.union!(dest::HyperLogLog{P}, src::HyperLogLog{P}) where {P}
    for i in 1:sizeof(dest)
        @inbounds dest.counts[i] = max(dest.counts[i], src.counts[i])
    end
    return dest
end


"""
    union(x::HyperLogLog{P}, y::HyperLogLog{P})

Create a new HLL identical to an HLL which has seen the union of the elements
`x` and `y` has seen.

# Examples
```
julia> # That c is longer than a or b is not guaranteed, but overwhelmingly likely
julia> c = union(a, b); length(c) ≥ length(a) && length(c) ≥ length(b)
true
```
"""
Base.union(x::HyperLogLog{P}, y::HyperLogLog{P}) where {P} = union!(copy(x), y)

function Base.copy!(dest::HyperLogLog{P}, src::HyperLogLog{P}) where {P}
    unsafe_copyto!(dest.counts, 1, src.counts, 1, UInt(sizeof(dest)))
    return dest
end

Base.copy(x::HyperLogLog) = copy!(typeof(x)(), x)

Base.:(==)(x::HyperLogLog{P}, y::HyperLogLog{P}) where {P} = x.counts == y.counts
Base.:(==)(x::HyperLogLog, y::HyperLogLog) = false # if x and y has different values of P

"""
    empty!(x::HyperLogLog)

Reset the HLL to its beginning state (i.e. "deleting" all elements from the HLL),
returning it.

# Examples
```
julia> empty!(a); length(a) # should return approximately 0
1
```
"""
Base.empty!(x::HyperLogLog) = (fill!(x.counts, 0x00); x)

"""
    isempty(x::HyperLogLog)

Return `true` if the HLL has not seen any elements, `false` otherwise.
This is guaranteed to be correct, and so can be `true` even when length(x) > 0.

# Examples
```
julia> a = HyperLogLog{14}(); (length(a), isempty(a))
(1, true)

>julia push!(a, 1); (length(a), isempty(a))
(1, false)
```
"""
Base.isempty(x::HyperLogLog) = all(i == 0x00 for i in x.counts)

# A 64 bit hash is split, the first P bits is the bin index, the other bits the observation
getbin(hll::HyperLogLog{P}, x::UInt64) where {P} = x >>> (64 - P) + 1

# Get number of trailing zeros + 1. We use the mask to prevent number of zeros
# from being overestimated due to any zeros in the bin part of the UInt64
function getzeros(hll::HyperLogLog{P}, x::UInt64) where {P}
    or_mask = ((UInt64(1) << P) - 1) << (64 - P)
    return trailing_zeros(x | or_mask) + 1
end

"""
    push!(hll::HyperLogLog, items...)

Add each item to the HLL. This has no effect if the HLL has seen the items before.

# Examples
```
julia> a = HyperLogLog{14}(); push!(a, 1,2,3,4,5,6,7,8,9); length(a)
9
```
"""
function Base.push!(hll::HyperLogLog, x)
    h = hash(x)
    bin = getbin(hll, h)
    @inbounds hll.counts[bin] = max(hll.counts[bin], getzeros(hll, h))
    return hll
end

function Base.push!(hll::HyperLogLog, values...)
    for value in values
        push!(hll, value)
    end
    return hll
end

# This corrects for systematic bias in the harmonic mean, see original paper.
function α(x::HyperLogLog{P}) where {P}
    if P == 4
        return 0.673
    elseif P == 5
        return 0.697
    elseif P == 6
        return 0.709
    else
        return 0.7213/(1 + 1.079/sizeof(x))
    end
end

# This accounts for systematic bias for low raw estimates.
# From https://ai.google/research/pubs/pub40671
# For license, see the constants.jl file
function bias(hll::HyperLogLog{P}, biased_estimate) where {P}
    rawarray = raw_arrays[P - 3]
    biasarray = bias_arrays[P - 3]
    firstindex = searchsortedfirst(rawarray, biased_estimate)
    # Raw count large, no need for bias correction
    if firstindex == length(rawarray) + 1
        return 0.0
    # Raw count too small, cannot be corrected. Maybe raise error?
    elseif firstindex == 1
        return biasarray[1]
    # Else linearly approximate the right value for bias
    else
        x1, x2 = rawarray[firstindex - 1], rawarray[firstindex]
        y1, y2 = biasarray[firstindex - 1], biasarray[firstindex]
        delta = (biased_estimate-x1)/(x2-x1) # relative distance of raw from x1
        return  y1 + delta * (y2-y1)
    end
end

"""
    length(hll::HyperLogLog{Precision})

Estimate the number of distinct elements the HLL has seen. The error depends on
the Precision parameter. This has low absolute rror when the estimate is small,
and low relative error when the estimate is high.

# Examples
```
julia> a = HyperLogLog{14}(); push!(a, 1,2,3,4,5,6,7,8); length(a)
9
```
"""
function Base.length(x::HyperLogLog{P}) where {P}
    # Harmonic mean estimates cardinality per bin. There are 2^P bins
    harmonic_mean = sizeof(x) / sum(1 / 1<<i for i in x.counts)
    biased_estimate = α(x) * sizeof(x) * harmonic_mean
    return round(Int, biased_estimate - bias(x, biased_estimate))
end
