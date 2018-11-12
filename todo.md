Redo performance graphs of Cuckoo and Bloom (insertion, fetching).

Add an "example use" sub-page for each datastructures. Reuse the existing HyperLogLog one but add some more flesh to it

__Potential future improvement__
Encode the cells of HyperLogLog? This will decrease memory consumption by ~25%, but will decrease speed a little. Right now, I think the memory requirement of HLLs is so low, people would prefer more speed than to save 4 KB of RAM per instance.


  | **Documentation**   |
  |:-----------------------------:|
  | [![][docs-stable-img]][docs-stable-url] |

  [docs-stable-img]: https://img.shields.io/badge/docs-stable-blue.svg
  [docs-stable-url]: https://juliadocs.github.io/Documenter.jl/stable
