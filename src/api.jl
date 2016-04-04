inds(A, d)               # index vector for dimension d (default 1:size(A, d))
inds(A)                  # tuple-of-inds
zeros(Int, -3:3, -1:5)   # creates matrix of size 7-by-7 with the given inds
fill(val, indexes...)    # likewise

A[first+1:(last+first)÷2]          # copy (or view) of the first half of array, skipping the first element

icat(a, b)  # index-preserving concatenation
# For example:
#    icat(7:10, 3)  7:10 is indexed with 1:4, so this creates a vector indexed from 1:5 (numbers aren't tied to an index)
#    icat(3, 7:10)  creates a vector indexed from 0:4
#    icat(5:7, 2:4) is an error, because they have overlapping indexes 1:3
#    icat(5:7, OffsetArray(2:4, 4:6))  indexed from 1:6
#    icat(5:7, OffsetArray(2:4, 5:7))  an error, non-contiguous indexes

# `index` and `stored` return "indexing hints," the laziest of wrappers
index(A, :, j)          # lazy-wrapper indicating that one wants indexes associated with column j of A
stored(A, :, j)         # just the stored values of A in column j
index(stored(A, :, j))  # just the row-indexes of the stored values in column j
index(A, :, ?)          # row-index iterator for an arbitrary (unknown) column of A
index(A, Val{2})        # similar to index(A, ?, :, ?...)
index(A, 2)             # sometimes-noninferrable variant of the above (some types won't need complicated inference, though)

couple(iter1, iter2)    # iterates over iter1, iter2 containers, keeping them in sync
# Do we want/need this? I suspect not (default would be `any`)
couple(any, stored(iter1), stored(iter2))  # visits i if either iter1[i] or iter2[i] has a value
couple(all, stored(iter1), stored(iter2))  # visits i if both iter1[i] and iter2[i] have values
