module TestHyperLogLog

using Test
using Probably

@testset "HyperLogLog" begin
include("hyperloglog.jl")
end

@testset "Cuckoo filter" begin
include("cuckoo_bucket.jl")
include("cuckoo_filter.jl")
end

@testset "Bloom filter" begin
include("bloom.jl")
end

@testset "Count-min sketch" begin
include("countmin.jl")
end

end # module
