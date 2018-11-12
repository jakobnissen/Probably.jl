# Cuckoo versus bloom filters

Bloom and cuckoo filters serve the same purpose, though they use quite different underlying algorithms. Each has strengths and weaknesses.

### Insertion (`push!`)

Bloom filters have infinite capacity, but the false positive rate (FPR) trends toward 1 as more distinct elements are added. The given "capacity" of a bloom filter is the number of element at which the false positive rate is below a given threshold.

In contrast, cuckoo filters have a finite capacity, and the FPR trends towards a desired maximum as the filter fills. Attempting to insert an object in a full filter makes the `push!` operation return `false`.

### Querying (`in`)

Bloom filters have false positives but never false negatives.

Cuckoo filters have false positives, and have no false negatives if a delete operation has never been performed on the filter. If a deletion operation has taken place, then because the *deletion* suffers from false positives, subsequent queries may return false negatives.

### Deletion (`pop!`)

Bloom filters do not support deletion.

Cuckoo filters support deletion. Deleting an object from a cuckoo filter may also delete any colliding objects.

### Merging (`union`)

Two bloom filters with the same parameters can always be merged.

Two cuckoo filters cannot be merged if they do not have the same parameters. Even if they do, the union of elements in the cuckoo filter may be above the capacity of the filter, which will cause the merge operation to fail.

## Memory, speed and scaling

### Bits per element

Both bloom and cuckoo filters have nonzero but insignificant memory overhead. Almost all the memory consumed go to storing the encoded data.

Cuckoo filters use slightly fewer bits per element to achieve a given false positive rate. On the other hand, cuckoo filters can only have a size that is a power-of-two. This means that given a specific maximal memory available, a bloom filter may fit the desired memory usage better than a cuckoo filter, and thus have a larger possible capacity.
