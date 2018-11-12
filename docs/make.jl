using Documenter, Probably

makedocs(sitename="Probably.jl", html_prettyurls=false,
        pages = Any[
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
)
