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

end # module
