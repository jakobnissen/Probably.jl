using Documenter, Probably

makedocs(
    format = :html,
    sitename = "Probably.jl",
    html_prettyurls = false,
    pages = [
        "Home" => "home.md",
        "HyperLogLog" => "hyperloglog.md",
        "Count-min sketch" => "countmin.md",
        "Cuckoo filter" => "cuckoo.md",
        "Bloom filter" => "bloom.md",
        hide("Cuckoo versus bloom filters" => "cuckoo_v_bloom.md"),
    ]
)

deploydocs(
    repo = "github.com/jakobnissen/Probably.jl.git",
    julia = "1.0",
    osname = "linux",
    target = "build",
    deps = nothing,
    make = nothing
)
