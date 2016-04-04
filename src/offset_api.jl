inds(A, d)               # index vector for dimension d (default 1:size(A, d))
inds(A)                  # tuple-of-inds
zeros(Int, (-3:3, -1:5)) # creates matrix of size 7-by-7 with the given inds
fill(val, (indexes...))
icat(a, b)  # index-preserving concatenation
# For example:
#    icat(7:10, 3)  7:10 is indexed with 1:4, so this creates a vector indexed from 1:5 (numbers aren't tied to an index)
#    icat(3, 7:10)  creates a vector indexed from 0:4
#    icat(5:7, 2:4) is an error, because they have overlapping indexes 1:3
#    icat(5:7, OffsetArray(2:4, 4:6))  indexed from 1:6
#    icat(5:7, OffsetArray(2:4, 5:7))  an error, non-contiguous indexes
