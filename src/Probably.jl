module Probably

export
    # From HyperLogLog
    HyperLogLog,
    # From CuckooFilter
    AbstractCuckooFilter,
    FastCuckoo,
    SmallCuckoo,
    fprof,
    capacityof,
    loadfactor,
    constrain,
    # From CountMinSketch
    CountMinSketch,
    add!,
    # From BloomFilter
    BloomFilter

include("hyperloglog/hyperloglog.jl")
include("cuckoo/filter.jl")
include("countmin/sketch.jl")
include("bloom/filter.jl")

end # module
