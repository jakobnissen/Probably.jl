@testset "Instantiation" begin
@test_throws ArgumentError x = BloomFilter(0, 4)
@test_throws ArgumentError x = BloomFilter(-1, 4)
@test_throws ArgumentError x = BloomFilter(10, 0)
@test_throws ArgumentError x = BloomFilter(10, -1)

x = BloomFilter(16, 3)
end

@testset "Equality" begin
x, y = BloomFilter(1000, 3), BloomFilter(1000, 3)
z, w = BloomFilter(2000, 3), BloomFilter(1000, 4)

@test x ==y
@test x != z
@test z != w
@test z != w

push!(x, "Hello!")
@test x != y
push!(y, "Hello!")
@test x == y
end

@testset "Isempty and empty!" begin
x = BloomFilter(1000, 3)
@test isempty(x)
push!(x, rand())
@test !isempty(x)
for i in 1:100
    push!(x, rand())
end
@test !isempty(x)
empty!(x)
@test isempty(x)
end

@testset "Copying" begin
x, y = BloomFilter(1000, 3), BloomFilter(1000, 3)
z, w = BloomFilter(2000, 3), BloomFilter(1000, 4)

@test_throws ArgumentError copy!(x, z)
@test_throws ArgumentError copy!(x, w)
@test_throws ArgumentError copy!(z, w)

push!(x, rand())
copy!(y, x)
@test x == y
for i in 1:100
    push!(x, rand())
    push!(y, rand())
end
@test x != y
z = copy(x)
@test x == z
copy!(y, z)
@test z == x == y
end

@testset "Pushing and membership" begin
x = BloomFilter(1000, 3)
s = collect(Set(rand(100)))
a, b = s[1:50], s[51:end]
for ai in a
    push!(x, ai)
end
all_in_ok = true
for ai in a
    all_in_ok &= ai in a
end
@test all_in_ok
false_positives = 0
for bi in b
    if bi in x
        false_positives += 1
    end
end
@test false_positives < 5
end

@testset "Union" begin
x, y = BloomFilter(1000, 3), BloomFilter(1000, 3)
a, b = rand(UInt8, 100), rand(UInt8, 100)
for (ai, bi) in zip(a, b)
    push!(x, ai)
    push!(y, bi)
end
@test x != y
z = union(x, y)
@test x != z
@test y != z
all_in_ok = true
for (ai, bi) in zip(a, b)
    all_in_ok &= ai in z
    all_in_ok &= bi in z
end
union!(x, y)
@test x == z
union!(y, z)
@test x == y == z
end
