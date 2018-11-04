module t

using Test
using Probably

@testset "Instantiation" begin
@test_throws TypeError CountMinSketch{Int}(1000, 25)
@test_throws TypeError CountMinSketch{10}(1000, 25)
@test_throws ArgumentError CountMinSketch{UInt8}(1000, 1)
@test_throws ArgumentError CountMinSketch{UInt8}(-5, 2)
@test_throws ArgumentError CountMinSketch{UInt8}(0, 2)

x = CountMinSketch{UInt32}(5000, 20)
y = CountMinSketch{UInt8}(1000, 5)
z = CountMinSketch(1000, 5)

@test x.len == 5000
@test x.width == 20
@test y.len == 1000
@test y.width == 5
@test typeof(y) === typeof(z)

@test eltype(y) === eltype(z) == UInt8
@test eltype(x) === UInt32
end

@testset "Empty and emptying" begin
x = CountMinSketch{UInt16}(1000, 4)
@test isempty(x)
push!(x, "hej")
@test !isempty(x)
for i in 1:100
    push!(x, rand())
end
@test !isempty(x)
len, width = x.len, x.width
empty!(x)
@test isempty(x)
@test len == x.len
@test width == x.width
end

@testset "Equality" begin
x, y = CountMinSketch{UInt64}(1000, 4), CountMinSketch{UInt64}(1000, 4)
z, w = CountMinSketch{UInt8}(1000, 4), CountMinSketch{UInt64}(1000, 6)

@test x == y
@test x != z
@test x != w
@test z != w

a = rand(100)
for i in a
    push!(x, i)
end
@test x != y
for i in a
    push!(y, i)
end
@test x == y
end

@testset "Copying" begin
x, y = CountMinSketch{UInt16}(1000, 4), CountMinSketch{UInt16}(1000, 4)
z, w = CountMinSketch{UInt32}(1000, 4), CountMinSketch{UInt16}(1000, 6)

@test_throws MethodError copy!(x, z)
@test_throws ArgumentError copy!(x, w)
@test_throws MethodError copy!(z, w)

a = rand(Int, 100)
for i in a
    push!(x, i)
end
@test x != y

x2 = CountMinSketch{UInt16}(1000, 4)
copy!(x2, x)
@test x == x2

for i in a
    push!(y, i)
end

@test x == y == x2
@test x == copy(x)
copy!(y, x)
@test x == y
end

@testset "Adding and retrieval" begin
x = CountMinSketch(1000, 4)
add!(x, 15, 7)
@test x[15] == 7 # Exact with only one

d = Dict(rand(Int)=>rand(10:15) for i in 1:100)
d[15] = 7

for (k, v) in d
    add!(x, k, v)
end

# Never underreports
all_more = true
for (k, v) in d
    all_more &= x[k] ≥ v
end
@test all_more

# Never overflows
add!(x, 15, 250)
@test x[15] == 255
end
end # module
