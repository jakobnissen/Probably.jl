using Documenter, Probably

makedocs(sitename="My Documentation", html_prettyurls=false,
        pages = Any[
        "Home" => "home.md",
        "HyperLogLog" => "hyperloglog.md",
        "Cuckoo filter" => "cuckoo.md",
        "Bloom filter" => "bloom.md"]
        )
