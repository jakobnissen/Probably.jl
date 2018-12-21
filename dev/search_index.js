var documenterSearchIndex = {"docs": [

{
    "location": "index.html#",
    "page": "Home",
    "title": "Home",
    "category": "page",
    "text": ""
},

{
    "location": "index.html#Probably.jl-Documentation-1",
    "page": "Home",
    "title": "Probably.jl Documentation",
    "category": "section",
    "text": "Probabilistic data structures in JuliaProbably.jl provides an implementation of common probabilistic data structures that are:Written in pure Julia\nBoth fast and memory-efficient\nGood for default or casual use cases, easy to use in other projects\nManipulated via functions with sensible names, often from Julia\'s Base libraryThis package does not attempt to:Provide a wide array of of functionality\nProvide structures 100% optimized for different use cases\nGloss over the limitation of the data structures. Instead, you are expected to understand in broad strokes how the data structures work before you use them."
},

{
    "location": "index.html#Package-features-1",
    "page": "Home",
    "title": "Package features",
    "category": "section",
    "text": "Probably.jl currently includes the following data structures:HyperLogLog\nCuckoo filter\nCount-min sketch\nBloom filter"
},

{
    "location": "hyperloglog.html#",
    "page": "HyperLogLog",
    "title": "HyperLogLog",
    "category": "page",
    "text": ""
},

{
    "location": "hyperloglog.html#HyperLogLog-1",
    "page": "HyperLogLog",
    "title": "HyperLogLog",
    "category": "section",
    "text": "_References: Original algorithm: Flajolet, Fusy, Gandouet & Meunier: \"Hyperloglog: The analysis of a near-optimal cardinality estimation algorithm\".With some of the modifications from: Heule, Nunkesser & Hall: \"HyperLogLog in practice: Algorithmic engineering of a state of the art cardinality estimation algorithm\"._"
},

{
    "location": "hyperloglog.html#What-it-is-1",
    "page": "HyperLogLog",
    "title": "What it is",
    "category": "section",
    "text": "An HyperLogLog is a very memory-efficient datastructure that keeps track of approximately how many distinct, hashable elements it\'s seen. A default HLL uses 16 KiB of memory and can return reliable estimates of up to some very large cardinality (on the order of 2^59 distinct elements).This estimate of cardinality has a median error of 0.5 %, and a 99 % chance of having an error less than 2.5 %, when the cardinality estimate is >1024. To accurately keep track of datasets smaller than 1024, use another datastructure like a Set.This implementation is not optimally memory-efficient, but it is fast. More advanced tricks can be found in the Heule et al. paper linked above, which increases accuracy and lowers memory usage for small N.The HLLs are not guaranteed to be threadsafe. To parallelize this implementation of HLL, each process/thread must operate on independent HLLs. These can then be efficiently merged using union or union! (or ∪). This is much faster than using atomic operations."
},

{
    "location": "hyperloglog.html#Usage-example-1",
    "page": "HyperLogLog",
    "title": "Usage example",
    "category": "section",
    "text": "In this example, let\'s say I\'m given 133 million fastq-sequences from a large sequencing project of Neanderthal bones. 133 million reads sounds like a lot, so, I\'m worried that the lab folk went a little overboard on the PCR and the same reads are present in many copies. Hence, I want to know how many unique reads there are. I don\'t care that the HyperLogLog doesn\'t fit in the cache, so I\'ll crank the P parameter up to 18 and spend the 256 KiB memory to maximize accuracy:hll = HyperLogLog{18}()\nreader = FASTQ.Reader(open(\"huge_file.fastq\", \"r\"))\nfor record in reader\n    seq = sequence(record) # we want a hashable DNA sequence    \n    push!(hll, seq)\nend\nprintln(\"Number of distinct FASTQ-sequences: \", length(hll))"
},

{
    "location": "hyperloglog.html#Interface-1",
    "page": "HyperLogLog",
    "title": "Interface",
    "category": "section",
    "text": ""
},

{
    "location": "hyperloglog.html#Construction-1",
    "page": "HyperLogLog",
    "title": "Construction",
    "category": "section",
    "text": "The accuracy of a HLL depends on its P parameter. You can construct a HLL with its P parameter directly:julia> hll = HyperLogLog{14}()\nHyperLogLog{14}()A P-value of 14 is considered default, so if you don\'t pass the parameter, 14 is assumed as default:julia> HyperLogLog{14}() == HyperLogLog()\ntrue"
},

{
    "location": "hyperloglog.html#Base.push!-Tuple{HyperLogLog,Any}",
    "page": "HyperLogLog",
    "title": "Base.push!",
    "category": "method",
    "text": "push!(hll::HyperLogLog, items...)\n\nAdd each item to the HLL. This has no effect if the HLL has seen the items before.\n\nExamples\n\njulia> a = HyperLogLog{14}(); push!(a, 1,2,3,4,5,6,7,8,9); length(a)\n9\n\n\n\n\n\n"
},

{
    "location": "hyperloglog.html#Base.length-Tuple{HyperLogLog}",
    "page": "HyperLogLog",
    "title": "Base.length",
    "category": "method",
    "text": "length(hll::HyperLogLog{Precision})\n\nEstimate the number of distinct elements the HLL has seen. The error depends on the Precision parameter. This has low absolute rror when the estimate is small, and low relative error when the estimate is high.\n\nExamples\n\njulia> a = HyperLogLog{14}(); push!(a, 1,2,3,4,5,6,7,8); length(a)\n9\n\n\n\n\n\n"
},

{
    "location": "hyperloglog.html#Central-functions-1",
    "page": "HyperLogLog",
    "title": "Central functions",
    "category": "section",
    "text": "Base.push!(x::HyperLogLog, val)\nBase.length(x::HyperLogLog)"
},

{
    "location": "hyperloglog.html#Base.isempty-Tuple{HyperLogLog}",
    "page": "HyperLogLog",
    "title": "Base.isempty",
    "category": "method",
    "text": "isempty(x::HyperLogLog)\n\nReturn true if the HLL has not seen any elements, false otherwise. This is guaranteed to be correct, and so can be true even when length(x) > 0.\n\nExamples\n\njulia> a = HyperLogLog{14}(); (length(a), isempty(a))\n(1, true)\n\n>julia push!(a, 1); (length(a), isempty(a))\n(1, false)\n\n\n\n\n\n"
},

{
    "location": "hyperloglog.html#Base.empty!-Tuple{HyperLogLog}",
    "page": "HyperLogLog",
    "title": "Base.empty!",
    "category": "method",
    "text": "empty!(x::HyperLogLog)\n\nReset the HLL to its beginning state (i.e. \"deleting\" all elements from the HLL), returning it.\n\nExamples\n\njulia> empty!(a); length(a) # should return approximately 0\n1\n\n\n\n\n\n"
},

{
    "location": "hyperloglog.html#Base.union!-Union{Tuple{P}, Tuple{HyperLogLog{P},HyperLogLog{P}}} where P",
    "page": "HyperLogLog",
    "title": "Base.union!",
    "category": "method",
    "text": "union!(dest::HyperLogLog{P}, src::HyperLogLog{P})\n\nOverwrite dest with the same result as union(dest, src), returning dest.\n\nExamples\n\njulia> # length(c) ≥ length(b) is not guaranteed, but overwhelmingly likely\njulia> c = union!(a, b); c === a && length(c) ≥ length(b)\ntrue\n\n\n\n\n\n"
},

{
    "location": "hyperloglog.html#Base.union-Union{Tuple{P}, Tuple{HyperLogLog{P},HyperLogLog{P}}} where P",
    "page": "HyperLogLog",
    "title": "Base.union",
    "category": "method",
    "text": "union(x::HyperLogLog{P}, y::HyperLogLog{P})\n\nCreate a new HLL identical to an HLL which has seen the union of the elements x and y has seen.\n\nExamples\n\njulia> # That c is longer than a or b is not guaranteed, but overwhelmingly likely\njulia> c = union(a, b); length(c) ≥ length(a) && length(c) ≥ length(b)\ntrue\n\n\n\n\n\n"
},

{
    "location": "hyperloglog.html#Misc-functions-1",
    "page": "HyperLogLog",
    "title": "Misc functions",
    "category": "section",
    "text": "note: Note\nHyperLogLog supports the following operations, which have no HyperLogLog-specific docstring because they behave as stated in the documentation in Base:Base.copy!\nBase.copy\nBase.sizeof # This one includes the underlying arrayBase.isempty(x::HyperLogLog)\nBase.empty!(x::HyperLogLog)\nBase.union!(dest::HyperLogLog{P}, src::HyperLogLog{P}) where {P}\nBase.union(x::HyperLogLog{P}, y::HyperLogLog{P}) where {P}"
},

{
    "location": "countmin.html#",
    "page": "Count-min sketch",
    "title": "Count-min sketch",
    "category": "page",
    "text": ""
},

{
    "location": "countmin.html#Count-min-sketch-1",
    "page": "Count-min sketch",
    "title": "Count-min sketch",
    "category": "section",
    "text": ""
},

{
    "location": "countmin.html#What-it-is-1",
    "page": "Count-min sketch",
    "title": "What it is",
    "category": "section",
    "text": "A count-min sketch is a probabilistic counter of hashable objects. Similar to bloom filters in structure, they exhibit false positives (may overcount), but no false negatives (never undercounts). Count-min sketches have two parameters: Length and width. Its accuracy is described by two numbers: ϵ describing its error and δ describing its probability of error. More rigorously, if N is the true count of an event, E is the estimate given by a sketch and T the total count of items in the sketch, E ≤ N + Tϵ with probability (1 - δ). The parameters of a sketch can be determined by length = 2/ϵ and depth = -log(δ)/log(2)."
},

{
    "location": "countmin.html#Adding-(add!)-1",
    "page": "Count-min sketch",
    "title": "Adding (add!)",
    "category": "section",
    "text": "Count-min sketches has infinite capacity, but adding elements steadily increases the probability of a miscounting other values. Add time is proportional to depth."
},

{
    "location": "countmin.html#Querying-(getindex)-1",
    "page": "Count-min sketch",
    "title": "Querying (getindex)",
    "category": "section",
    "text": "Querying time is proportional to depth. It has a certain risk of reporting too high counts, but no risk of undercounting."
},

{
    "location": "countmin.html#Subtracting/deletion.-1",
    "page": "Count-min sketch",
    "title": "Subtracting/deletion.",
    "category": "section",
    "text": "Count-min sketches do not support subtracting or deleting."
},

{
    "location": "countmin.html#Usage-example-1",
    "page": "Count-min sketch",
    "title": "Usage example",
    "category": "section",
    "text": "I don\'t know anything about astronomy, but indulge me: Say I want to count how many times different stars have been observed. Sightings are available in a public database. There\'s about 1.4 billion known stars, with about 5 billion sightings. I have 10 GB of available RAM to balance ϵ and δ.First, I decide that a UInt8 (maximum count of 255) is fine - I don\'t care that Polaris have been observed 100,000 times.Most stars have a low count, so I really care about miscounts not being too large, and I care less about them being frequent or infrequent, so I should minimize ϵ rahter than δ, which means maximizing length rather than depth. So if I pick width = 4 and length = 2.5e9. This means the probability of miscounting with 4*2/10e4 * 5e9 = 4 with a probability of exp(-4*log(2)) 6.25%:sketch = CountMinSketch(2.5e9, 4)\n\nfor star in catalogue\n    push!(sketch, star) # same as adding one using add!\nend\n\n# How many times have a particular star observed?\nprintln(sketch[\"HD 143183\"])"
},

{
    "location": "countmin.html#Interface-1",
    "page": "Count-min sketch",
    "title": "Interface",
    "category": "section",
    "text": ""
},

{
    "location": "countmin.html#Construction-1",
    "page": "Count-min sketch",
    "title": "Construction",
    "category": "section",
    "text": "At the moment, count-min sketches can only be constructed from the parameters length and width:sketch = CountMinSketch{UInt8}(10000, 5)Although the default eltype of count-min sketches are UInt8, so you can avoid specifying that:sketch = CountMinSketch(10000, 5)"
},

{
    "location": "countmin.html#Base.getindex-Tuple{CountMinSketch,Any}",
    "page": "Count-min sketch",
    "title": "Base.getindex",
    "category": "method",
    "text": "getindex(sketch::CountMinSketch, item)\n\nGet the estimated count of item. This is never underestimated, but may be overestimated.\n\n\n\n\n\n"
},

{
    "location": "countmin.html#Probably.add!-Tuple{CountMinSketch,Any,Any}",
    "page": "Count-min sketch",
    "title": "Probably.add!",
    "category": "method",
    "text": "add!(sketch::CountMinSketch, val, count)\n\nAdd count number of val to the sketch. For increased speed, let count be of the same type as eltype(sketch).\n\nExamples\n\njulia> sketch = CountMinSketch(1 << 24, 4);\njulia> add!(sketch, \"hello\", eltype(sketch)(5));\njulia> sketch[\"hello\"]\n5\n\n\n\n\n\n"
},

{
    "location": "countmin.html#Base.push!-Tuple{CountMinSketch,Any}",
    "page": "Count-min sketch",
    "title": "Base.push!",
    "category": "method",
    "text": "push!(sketch::CountMinSketch, val)\n\nAdd val to the sketch once.\n\nExamples\n\njulia> sketch = CountMinSketch(1 << 24, 4);\njulia> push!(sketch, \"hello\");\njulia> sketch[\"hello\"]\n1\n\n\n\n\n\n"
},

{
    "location": "countmin.html#Central-functions-1",
    "page": "Count-min sketch",
    "title": "Central functions",
    "category": "section",
    "text": "Base.getindex(sketch::CountMinSketch, index)\nadd!(sketch::CountMinSketch, item, count)\nBase.push!(sketch::CountMinSketch, item)"
},

{
    "location": "countmin.html#Base.:+-Union{Tuple{T}, Tuple{CountMinSketch{T},CountMinSketch{T}}} where T",
    "page": "Count-min sketch",
    "title": "Base.:+",
    "category": "method",
    "text": "+(x::CountMinSketch, y::CountMinSketch)\n\nAdd two count-min sketches together. Will not work if x and y do not share parameters T, length and width. The result will be a sketch with the summed counts of the two input sketches.\n\nExamples\n\njulia> x, y = CountMinSketch(1000, 4), CountMinSketch(1000, 4);\n\njulia> add!(x, \"hello\", 4); add!(y, \"hello\", 19);\n\njulia> z = x + y; Int(z[\"hello\"])\n23\n\n\n\n\n\n"
},

{
    "location": "countmin.html#Probably.fprof-Tuple{CountMinSketch}",
    "page": "Count-min sketch",
    "title": "Probably.fprof",
    "category": "method",
    "text": "fprof(sketch::CountMinSketch)\n\nEstimate the probability of miscounting an element in the sketch.\n\n\n\n\n\n"
},

{
    "location": "countmin.html#Base.haskey-Tuple{CountMinSketch,Any}",
    "page": "Count-min sketch",
    "title": "Base.haskey",
    "category": "method",
    "text": "haskey(sketch::CountMinSketch)\n\nCheck if sketch[val] > 0.\n\n\n\n\n\n"
},

{
    "location": "countmin.html#Base.empty!-Tuple{CountMinSketch}",
    "page": "Count-min sketch",
    "title": "Base.empty!",
    "category": "method",
    "text": "empty!(sketch::CountMinSketch)\n\nReset counts of all items to zero, returning the sketch to initial state.\n\n\n\n\n\n"
},

{
    "location": "countmin.html#Base.isempty-Tuple{CountMinSketch}",
    "page": "Count-min sketch",
    "title": "Base.isempty",
    "category": "method",
    "text": "isempty(sketch::CountMinSketch)\n\nCheck if no items have been added to the sketch.\n\n\n\n\n\n"
},

{
    "location": "countmin.html#Misc-functions-1",
    "page": "Count-min sketch",
    "title": "Misc functions",
    "category": "section",
    "text": "note: Note\nCount-min sketches support the following operations, which have no specific docstring because they behave as stated in the documentation in Base:Base.eltype\nBase.copy!\nBase.copy\nBase.sizeof # This one includes the underlying arrayBase.:+(x::CountMinSketch{T}, y::CountMinSketch{T}) where {T}\nfprof(sketch::CountMinSketch)\nBase.haskey(sketch::CountMinSketch, key)\nBase.empty!(sketch::CountMinSketch)\nBase.isempty(sketch::CountMinSketch)"
},

{
    "location": "cuckoo.html#",
    "page": "Cuckoo filter",
    "title": "Cuckoo filter",
    "category": "page",
    "text": ""
},

{
    "location": "cuckoo.html#Cuckoo-filter-1",
    "page": "Cuckoo filter",
    "title": "Cuckoo filter",
    "category": "section",
    "text": "Reference: Fan, Andersen, Kaminsky & Mitzenmacher: \"Cuckoo Filter: Practically Better Than Bloom\"note: Note\nSee also the page: Cuckoo versus bloom filters"
},

{
    "location": "cuckoo.html#What-it-is-1",
    "page": "Cuckoo filter",
    "title": "What it is",
    "category": "section",
    "text": "A cuckoo filter is conceptually similar to a bloom filter, even though the underlying algorithm is quite different.The cuckoo filter is similar to a Set. Hashable objects can be pushed into the filter, but objects cannot be extracted from the filter. Querying the filter, i.e. asking whether an object is in a filter is fast, but cuckoo filters has a certain probability of falsely returning true when querying about an object not actually in the filter. When querying an object that is in the filter, it is guaranteed to return true.A cuckoo filter is defined by two parameters, F and its length L. Memory usage is F*L/2 bytes plus 50-ish bytes of overhead, and the false positive rate is approximately 9*(N/L)*(2^-F) where N is the number of elements in the filter."
},

{
    "location": "cuckoo.html#Querying-(in)-1",
    "page": "Cuckoo filter",
    "title": "Querying (in)",
    "category": "section",
    "text": "Querying takes one cache access plus either 1 or 2 random memory access depending on the values of N, F and L, and so can be thought of as being constant. When querying about an object in the filter, it is guaranteed to return true, unless deletion operations have been done on the filrter. Querying about objects not in the filter returns true with a probability approximately to 9*(N/L)*(2^-F).In general, two distinct objects A and B will have a 1/(2^F-1) chance of sharing so-called \"fingerprints\". Independently, each object is assigned two \"buckets\" in the range 1:L/4, and inserted in an arbitrary of the two buckets. If objects A and B share fingerprints, and object A is in one of B\'s buckets, the existence of A will make a query for B return true, even when it\'s not in the filter."
},

{
    "location": "cuckoo.html#Pushing-(push!)-1",
    "page": "Cuckoo filter",
    "title": "Pushing (push!)",
    "category": "section",
    "text": "Only hashable objects can be inserted into the filter. Inserting time is stochastic, but its expected duration is proportional to 1/(1 - N/L). To avoid infinite insertion times as N approaches L, an insert operation may fail if the filter is too full. A failed push operation returns false.Pushing may yield false positives: If an object A exists in the filter, and querying for object B would falsely return true, then pushing B to the filter has a probability 1/2 + 1/2 * N/L of returning true while doing nothing, because B is falsely believed to already be in the filter."
},

{
    "location": "cuckoo.html#Deletion-(pop!)-1",
    "page": "Cuckoo filter",
    "title": "Deletion (pop!)",
    "category": "section",
    "text": "Objects can be deleted from the filter. Deleting operation also exhibits false positives: If B has been pushed to the filter, falsely returning success, then deleting A will also delete B.Deletion of objects is fast and constant time, except if the filter is at full capacity. In that case, it will attempt to self-organize after a deletion to allow new objects to be pushed. This might take up to 200 microseconds."
},

{
    "location": "cuckoo.html#FastCuckoo-and-SmallCuckoo-1",
    "page": "Cuckoo filter",
    "title": "FastCuckoo and SmallCuckoo",
    "category": "section",
    "text": "Probably.jl comes with two different implementations of the cuckoo filter: FastCuckoo and SmallCuckoo. The latter uses a more complicated encoding scheme to achieve a slightly smaller memory footprint, but which also make all operations slower. The following plot shows how the speed of pushing objects depend on the load factor, i.e. how full the filter is, and how FastCuckoos are ~2.5x faster than SmallCuckoos, but that the SmallCuckoo uses about 10% less memory. FastCuckoo is displayed in blue, SmallCuckoo in orange.(Image: )"
},

{
    "location": "cuckoo.html#Usage-example-1",
    "page": "Cuckoo filter",
    "title": "Usage example",
    "category": "section",
    "text": "For this example, let\'s say I have a stream of kmers that I want to count. Of course I use BioJulia, so these kmers are represented by a DNAKmer{31} object. I suspect my stream has up to 2 billion different kmers, so keeping a counting Dict would use up all my memory. However, most kmers are measurement errors that only appear once and that I do not need spend memory on keeping count of. So I keep track of which kmers I\'ve seen using a Cuckoo filter. If I see a kmer more than once, I add it to the Dict.params = constrain(SmallCuckoo, fpr=0.02, capacity=2_000_000_000)\nif params.memory > 4e9 # I\'m only comfortable using 4 GB of memory for this\n    error(\"Too little memory :(\")\nend\nfilter = SmallCuckoo{params.F}(params.nfingerprints)\ncounts = Dict{Kmer, UInt8}() # Don\'t need to count higher than 255\n\nfor kmer in each(DNAKmer{31}, fastq_parser)\n    if kmer in filter\n        # Only add kmers we\'ve seen before\n        count = min(0xfe, get(counts, kmer, 0x01)) # No integer overflow\n        counts[kmer] = count + 0x01\n    else\n        push!(filter, kmer)\n    end\nend"
},

{
    "location": "cuckoo.html#Interface-1",
    "page": "Cuckoo filter",
    "title": "Interface",
    "category": "section",
    "text": ""
},

{
    "location": "cuckoo.html#Construction-1",
    "page": "Cuckoo filter",
    "title": "Construction",
    "category": "section",
    "text": "A cuckoo filter can be constructed directly from the two parameters F and L, where L is the number of fingerprint slots in the fingerprint. Remember that L should be a power-of-two:julia> FastCuckoo{12}(2^32) # F=12, L=2^32, about 6 GiB in sizeHowever, typically, one wants to construct cuckoo filters under some kind of constrains: Perhaps I need to store at least 1.1 billion distinct elements, with a maximal false positive rate of 0.004. For this purpose, use the constrain function.This function takes a type and two of three keyword arguments:fpr: Maximal false positive rate\nmemory: Maximal memory usage\ncapacity: Minimum number of distinct elements it can containIt returns a NamedTuple with the parameters for an object of the specified type which fits the criteria:julia> constrain(SmallCuckoo, fpr=0.004, capacity=1.1e9)\n(F = 11, nfingerprints = 2147483648, fpr = 0.002196371220581028, memory = 2952790074, capacity = 2040109466)Having passed false positive rate and capacity, the function determined the smallest possible SmallCuckoo that fits these criteria. We can see from the fields F and nfingerprints that such a SmallCuckoo can be constructed with:SmallCuckoo{11}(2147483648)Furthermore, we can also see that those particular constrains were quite unlucky: The actual false positive rate of this filter will be ~0.0022 (at full capacity), and its actual capacity will be ~2 billion elements. It is not possible to create a smaller SmallCuckoo which fits the given criteria."
},

{
    "location": "cuckoo.html#Base.in-Tuple{Any,AbstractCuckooFilter}",
    "page": "Cuckoo filter",
    "title": "Base.in",
    "category": "method",
    "text": "in(item, filter::AbstractCuckooFilter)\n\nCheck if an item is in the cuckoo filter. This can sometimes erroneously return true, but never erroneously returns false, unless a pop! operation has been performed on the filter.\n\n\n\n\n\n"
},

{
    "location": "cuckoo.html#Base.push!-Tuple{AbstractCuckooFilter,Any}",
    "page": "Cuckoo filter",
    "title": "Base.push!",
    "category": "method",
    "text": "push!(filter::AbstractCuckooFilter, items...)\n\nInsert one or more items into the cuckoo filter. Returns true if all inserts was successful and false otherwise.\n\n\n\n\n\n"
},

{
    "location": "cuckoo.html#Base.pop!-Tuple{AbstractCuckooFilter,Any}",
    "page": "Cuckoo filter",
    "title": "Base.pop!",
    "category": "method",
    "text": "pop!(filter::AbstractCuckooFilter, item)\n\nDelete an item from the cuckoo filter, returning the filter. Does not throw an error if the item does not exist. Has a risk of deleting other items if they collide with the target item in the filter.\n\nExamples\n\njulia> a = FastCuckoo{12}(2^4); push!(a, 1); push!(a, 868)\njulia> pop!(a, 1); # Remove 1, this accidentally deletes 868 also\njulia> isempty(a)\ntrue\n\n\n\n\n\n"
},

{
    "location": "cuckoo.html#Central-functions-1",
    "page": "Cuckoo filter",
    "title": "Central functions",
    "category": "section",
    "text": "Base.in(item, filter::AbstractCuckooFilter)\nBase.push!(filter::AbstractCuckooFilter, item)\nBase.pop!(filter::AbstractCuckooFilter, item)"
},

{
    "location": "cuckoo.html#Base.isempty-Tuple{AbstractCuckooFilter}",
    "page": "Cuckoo filter",
    "title": "Base.isempty",
    "category": "method",
    "text": "isempty(x::AbstractCuckooFilter)\n\nTest if the filter contains no elements. Guaranteed to be correct.\n\nExamples\n\njulia> a = FastCuckoo{12}(1<<12); isempty(a)\ntrue\n\n\n\n\n\n"
},

{
    "location": "cuckoo.html#Base.empty!-Tuple{AbstractCuckooFilter}",
    "page": "Cuckoo filter",
    "title": "Base.empty!",
    "category": "method",
    "text": "empty!(x::AbstractCuckooFilter)\n\nRemoves all objects from the cuckoo filter, resetting it to initial state.\n\nExamples\n\njulia> a = FastCuckoo{12}(1<<12); push!(a, \"Hello\"); isempty(a)\nfalse\n\njulia> empty!(a); isempty(a)\ntrue\n\n\n\n\n\n"
},

{
    "location": "cuckoo.html#Base.union!-Tuple{AbstractCuckooFilter}",
    "page": "Cuckoo filter",
    "title": "Base.union!",
    "category": "method",
    "text": "union!(dest::HyperLogLog{P}, src::HyperLogLog{P})\n\nOverwrite dest with the same result as union(dest, src), returning dest.\n\nExamples\n\njulia> # length(c) ≥ length(b) is not guaranteed, but overwhelmingly likely\njulia> c = union!(a, b); c === a && length(c) ≥ length(b)\ntrue\n\n\n\n\n\nunion!(dst::AbstractCuckooFilter{F}, src::AbstractCuckooFilter{F})\n\nAttempt to add all elements of source filter to destination filter. If destination runs out of space, abort the copying and return (destination, false). Else, return (destination, true). Both filters must have the same length and F value.\n\n\n\n\n\n"
},

{
    "location": "cuckoo.html#Base.union-Tuple{AbstractCuckooFilter}",
    "page": "Cuckoo filter",
    "title": "Base.union",
    "category": "method",
    "text": "union(x::HyperLogLog{P}, y::HyperLogLog{P})\n\nCreate a new HLL identical to an HLL which has seen the union of the elements x and y has seen.\n\nExamples\n\njulia> # That c is longer than a or b is not guaranteed, but overwhelmingly likely\njulia> c = union(a, b); length(c) ≥ length(a) && length(c) ≥ length(b)\ntrue\n\n\n\n\n\nunion(x::AbstractCuckooFilter{F}, y::AbstractCuckooFilter{F})\n\nAttempt to create a new cuckoo fitler with the same length and F value as x and y, and with the union of their elements. If the new array does not have enough space, returns (newfilter, false), else returns (newfilter, true). Both filters must have the same length and F value.\n\n\n\n\n\n"
},

{
    "location": "cuckoo.html#Probably.loadfactor-Tuple{AbstractCuckooFilter}",
    "page": "Cuckoo filter",
    "title": "Probably.loadfactor",
    "category": "method",
    "text": "loadfactor(x::AbstractCuckooFilter)\n\nReturns fraction of filled fingerprint slots, i.e. how full the filter is.\n\nExamples\n\njulia> a = FastCuckoo{12}(1<<12);\njulia> for i in 1:1<<11 push!(i, a) end; loadfactor(a)\n0.5\n\n\n\n\n\n"
},

{
    "location": "cuckoo.html#Probably.fprof",
    "page": "Cuckoo filter",
    "title": "Probably.fprof",
    "category": "function",
    "text": "fprof(::Type{AbstractCuckooFilter{F}}) where {F}\nfprof(x::AbstractCuckooFilter)\n\nGet the false positive rate for a fully filled AbstractCuckooFilter{F}. The FPR is proportional to the fullness (a.k.a load factor).\n\n\n\n\n\nfprof(sketch::CountMinSketch)\n\nEstimate the probability of miscounting an element in the sketch.\n\n\n\n\n\n"
},

{
    "location": "cuckoo.html#Probably.capacityof",
    "page": "Cuckoo filter",
    "title": "Probably.capacityof",
    "category": "function",
    "text": "capacityof(filter::AbstractCuckooFilter)\n\nEstimate the number of distinct elements that can be pushed to the filter before adding more will fail. Since push failures are probabilistic, this is not accurate, but for filters with a capacity of thousands or more, this is rarely more than 1% off.\n\n\n\n\n\n"
},

{
    "location": "cuckoo.html#Probably.constrain-Tuple{Type{AbstractCuckooFilter}}",
    "page": "Cuckoo filter",
    "title": "Probably.constrain",
    "category": "method",
    "text": "constrain(T<:AbstractCuckooFilter; fpr=nothing, mem=nothing, capacity=nothing)\n\nGiven a subtype of AbstractCuckooFilter and two of three keyword arguments, as constrains, optimize the elided keyword argument. Returns a NamedTuple with (F, nfingerprints, fpr, memory, capacity), which applies to an instance of the optimized CuckooFilter.\n\nExamples\n\njulia> # FastCuckoo with FPR ≤ 0.001, and memory usage ≤ 250_000_000 bytes\n\njulia> c = constrain(FastCuckoo, fpr=0.001, memory=250_000_000)\n(F = 14, nfingerprints = 134217728, fpr = 0.0005492605216655955, memory = 234881081,\ncapacity = 127506842)\n\njulia> x = FastCuckoo{c.F}(c.nfingerprints); # capacity optimized\n\njulia> fprof(x), sizeof(x), capacityof(x) # not always exactly the estimate\n(0.0005492605216655955, 234881081, 127506842)\n\n\n\n\n\n"
},

{
    "location": "cuckoo.html#Misc-functions-1",
    "page": "Cuckoo filter",
    "title": "Misc functions",
    "category": "section",
    "text": "note: Note\nCuckoo filters supports the following operations, which have no cuckoo-specific docstring because they behave as stated in the documentation in Base:Base.copy!\nBase.copy\nBase.sizeof # This one includes the underlying arrayBase.isempty(filter::AbstractCuckooFilter)\nBase.empty!(filter::AbstractCuckooFilter)\nBase.union!(filter::AbstractCuckooFilter)\nBase.union(filter::AbstractCuckooFilter)\nloadfactor(filter::AbstractCuckooFilter)\nfprof\ncapacityof\nconstrain(::Type{AbstractCuckooFilter})"
},

{
    "location": "bloom.html#",
    "page": "Bloom filter",
    "title": "Bloom filter",
    "category": "page",
    "text": ""
},

{
    "location": "bloom.html#Bloom-filter-1",
    "page": "Bloom filter",
    "title": "Bloom filter",
    "category": "section",
    "text": "Reference: Bloom: \"Space/time trade-offs in hash coding with allowable errors\"note: Note\nSee also the page: Cuckoo versus bloom filters"
},

{
    "location": "bloom.html#What-it-is-1",
    "page": "Bloom filter",
    "title": "What it is",
    "category": "section",
    "text": "A bloom filter is the prototypical probabilistic data structure. Elements can be added to a bloom filter, and afterwards, the filter can be queried about whether or not an element is in the filter. A bloom filter exhibits false positives, but not false negatives. In other words, a bloom filter will sometimes report an object to be present when it in fact is not, but whenever the object is not found in the bloom filter, it is guaranteed to truly not be in the filter. Element cannot be extracted from a bloom filter.A bloom filter is parameterized by two parameters, its length, m and the parameter k. Memory usage is m/8 bytes plus a few bytes of overhead.Bloom filters have infinite capacity, but their false positive rates asymptotically approach 1 as more objects are added. The capacity given for a bloom filter by this package refers to the number of distinct elements at which the expected false positive rate is below a given threshold."
},

{
    "location": "bloom.html#Querying-(in)-1",
    "page": "Bloom filter",
    "title": "Querying (in)",
    "category": "section",
    "text": "Querying time is constant. A filter with parameters m and k containing N distinct object has an expected false positive rate of (1-exp(-k*N/m))^k."
},

{
    "location": "bloom.html#Pushing-(push!)-1",
    "page": "Bloom filter",
    "title": "Pushing (push!)",
    "category": "section",
    "text": "Pushing time is constant and does not change the memory usage of the bloom filter. All hashable object can be pushed to the filter."
},

{
    "location": "bloom.html#Deletion-1",
    "page": "Bloom filter",
    "title": "Deletion",
    "category": "section",
    "text": "Bloom filters do not support deletion."
},

{
    "location": "bloom.html#Usage-example-1",
    "page": "Bloom filter",
    "title": "Usage example",
    "category": "section",
    "text": "Let\'s use the same example as for the Cuckoo filter: Again, I have a stream of kmers that I want to count. Of course I use BioJulia, so these kmers are represented by a DNAKmer{31} object. I suspect my stream has up to 2 billion different kmers, so keeping a counting Dict would use up all my memory. However, most kmers are measurement errors that only appear once and that I do not need spend memory on keeping count of. So I keep track of which kmers I\'ve seen using a Cuckoo filter. If I see a kmer more than once, I add it to the Dict.params = constrain(BloomFilter, fpr=0.02, capacity=2_000_000_000)\nif params.memory > 4e9 # I\'m only comfortable using 4 GB of memory for this\n    error(\"Too little memory :(\")\nend\nfilter = BloomFilter(params.m, params.k)\ncounts = Dict{Kmer, UInt8}() # Don\'t need to count higher than 255\n\nfor kmer in each(DNAKmer{31}, fastq_parser)\n    if kmer in filter\n        # Only add kmers we\'ve seen before\n        count = min(0xfe, get(counts, kmer, 0x01)) # No integer overflow\n        counts[kmer] = count + 0x01\n    else\n        push!(filter, kmer)\n    end\nend"
},

{
    "location": "bloom.html#Interface-1",
    "page": "Bloom filter",
    "title": "Interface",
    "category": "section",
    "text": ""
},

{
    "location": "bloom.html#Construction-1",
    "page": "Bloom filter",
    "title": "Construction",
    "category": "section",
    "text": "Bloom filters can be constructed directly given m and k:x = BloomFilter(100_000_000, k=10)And this will work just fine. However, in typical cases, people want to construct bloom filters with a set of constrains like \"I have 100 MB memory and I want to hold object with a false positive rate of at most 5%\". For this purpose, use the constrain function.This function takes a type and two of three keyword arguments:fpr: Maximal false positive rate\nmemory: Maximal memory usage\ncapacity: Minimum number of distinct elements it can containIt returns a NamedTuple with the parameters for an object of the specified type which fits the criteria:julia> constrain(BloomFilter, fpr=0.05, memory=100_000_000)\n(m = 799999808, k = 4, fpr = 0.04999999240568489, memory = 100000000, capacity = 128061884)This means the optimal bloom filter consuming less than 100 MB of RAM and having a FPR of less than 0.05 can be constructed by:x = BloomFilter(799999808, 4)"
},

{
    "location": "bloom.html#Base.in-Tuple{Any,BloomFilter}",
    "page": "Bloom filter",
    "title": "Base.in",
    "category": "method",
    "text": "in(item, filter::BloomFilter)\n\nDetermine if item is in bloom filter. This sometimes returns true when the correct answer is false, but never returns false when the correct answer is true.\n\n\n\n\n\n"
},

{
    "location": "bloom.html#Base.push!-Tuple{BloomFilter,Vararg{Any,N} where N}",
    "page": "Bloom filter",
    "title": "Base.push!",
    "category": "method",
    "text": "push!(filter::BloomFilter, items...)\n\nAdd one or more hashable items to the bloom filter.\n\n\n\n\n\n"
},

{
    "location": "bloom.html#Central-functions-1",
    "page": "Bloom filter",
    "title": "Central functions",
    "category": "section",
    "text": "Base.in(item, filter::BloomFilter)\nBase.push!(filter::BloomFilter, item...)"
},

{
    "location": "bloom.html#Base.length-Tuple{BloomFilter}",
    "page": "Bloom filter",
    "title": "Base.length",
    "category": "method",
    "text": "length(filter::BloomFilter) -> Float64\n\nProvide an estimate of the number of distinct elements in the filter. This may return Inf if the filter is entirely full.\n\nExamples\n\njulia> a = BloomFilter(10000, 4); for i in 1:5000 push!(a, i) end; length(a)\n4962.147247984721\n\n\n\n\n\n"
},

{
    "location": "bloom.html#Base.isempty-Tuple{BloomFilter}",
    "page": "Bloom filter",
    "title": "Base.isempty",
    "category": "method",
    "text": "isempty(filter::BloomFilter)\n\nDetermine if bloom filter is empty, i.e. has no elements in it. This is guaranteed to be correct, but does not mean the fitler consumes no RAM.\n\n\n\n\n\n"
},

{
    "location": "bloom.html#Base.empty!-Tuple{BloomFilter}",
    "page": "Bloom filter",
    "title": "Base.empty!",
    "category": "method",
    "text": "empty!(filter::BloomFilter)\n\nRemove all elements from BloomFilter, resetting it to initial state.\n\n\n\n\n\n"
},

{
    "location": "bloom.html#Probably.constrain-Tuple{Type{BloomFilter}}",
    "page": "Bloom filter",
    "title": "Probably.constrain",
    "category": "method",
    "text": "constrain(Type{BloomFilter}; fpr=nothing, mem=nothing, capacity=nothing)\n\nGiven BloomFilter and two of three keyword arguments, as constrains, optimize the elided keyword argument. Returns a NamedTuple with (m, k, fpr, memory, capacity), which applies to the optimized Bloom filter.\n\nExamples\n\njulia> # Bloom filter with FPR ≤ 0.05, and memory usage ≤ 50_000_000 bytes\n\njulia> c = constrain(BloomFilter, fpr=0.05, memory=50_000_000)\n(m = 399999808, k = 4, fpr = 0.049999979847949585, memory = 50000000, capacity = 6403092\n1)\n\njulia> x = BloomFilter(c.m, c.k); # capacity optimized\n\n\n\n\n\n"
},

{
    "location": "bloom.html#Misc-functions-1",
    "page": "Bloom filter",
    "title": "Misc functions",
    "category": "section",
    "text": "note: Note\nBloom filters supports the following operations, which have no bloom-specific docstring because they behave as stated in the documentation in Base:Base.copy!\nBase.copy\nBase.union!\nBase.union\nBase.sizeof # This one includes the underlying arrayBase.length(filter::BloomFilter)\nBase.isempty(filter::BloomFilter)\nBase.empty!(filter::BloomFilter)\nconstrain(::Type{BloomFilter}; fpr, memory, capacity)"
},

{
    "location": "cuckoo_v_bloom.html#",
    "page": "Cuckoo versus bloom filters",
    "title": "Cuckoo versus bloom filters",
    "category": "page",
    "text": ""
},

{
    "location": "cuckoo_v_bloom.html#Cuckoo-versus-bloom-filters-1",
    "page": "Cuckoo versus bloom filters",
    "title": "Cuckoo versus bloom filters",
    "category": "section",
    "text": "Bloom and cuckoo filters serve the same purpose, though they use quite different underlying algorithms. Each has strengths and weaknesses."
},

{
    "location": "cuckoo_v_bloom.html#Insertion-(push!)-1",
    "page": "Cuckoo versus bloom filters",
    "title": "Insertion (push!)",
    "category": "section",
    "text": "Bloom filters have infinite capacity, but the false positive rate (FPR) trends toward 1 as more distinct elements are added. The given \"capacity\" of a bloom filter is the number of element at which the false positive rate is below a given threshold.In contrast, cuckoo filters have a finite capacity, and the FPR trends towards a desired maximum as the filter fills. Attempting to insert an object in a full filter makes the push! operation return false."
},

{
    "location": "cuckoo_v_bloom.html#Querying-(in)-1",
    "page": "Cuckoo versus bloom filters",
    "title": "Querying (in)",
    "category": "section",
    "text": "Bloom filters have false positives but never false negatives.Cuckoo filters have false positives, and have no false negatives if a delete operation has never been performed on the filter. If a deletion operation has taken place, then because the deletion suffers from false positives, subsequent queries may return false negatives."
},

{
    "location": "cuckoo_v_bloom.html#Deletion-(pop!)-1",
    "page": "Cuckoo versus bloom filters",
    "title": "Deletion (pop!)",
    "category": "section",
    "text": "Bloom filters do not support deletion.Cuckoo filters support deletion. Deleting an object from a cuckoo filter may also delete any colliding objects."
},

{
    "location": "cuckoo_v_bloom.html#Merging-(union)-1",
    "page": "Cuckoo versus bloom filters",
    "title": "Merging (union)",
    "category": "section",
    "text": "Two bloom filters with the same parameters can always be merged.Two cuckoo filters cannot be merged if they do not have the same parameters. Even if they do, the union of elements in the cuckoo filter may be above the capacity of the filter, which will cause the merge operation to fail."
},

{
    "location": "cuckoo_v_bloom.html#Memory,-speed-and-scaling-1",
    "page": "Cuckoo versus bloom filters",
    "title": "Memory, speed and scaling",
    "category": "section",
    "text": ""
},

{
    "location": "cuckoo_v_bloom.html#Bits-per-element-1",
    "page": "Cuckoo versus bloom filters",
    "title": "Bits per element",
    "category": "section",
    "text": "Both bloom and cuckoo filters have nonzero but insignificant memory overhead. Almost all the memory consumed go to storing the encoded data.Cuckoo filters use slightly fewer bits per element to achieve a given false positive rate. On the other hand, cuckoo filters can only have a size that is a power-of-two. This means that given a specific maximal memory available, a bloom filter may fit the desired memory usage better than a cuckoo filter, and thus have a larger possible capacity."
},

]}
