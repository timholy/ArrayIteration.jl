module ArrayIteration

import Base: getindex, setindex!, start, next, done, length, eachindex, show, parent, isless
using Base: ReshapedArray, ReshapedIndex, linearindexing, LinearFast, LinearSlow, LinearIndexing
using Base.PermutedDimsArrays: PermutedDimsArray
using Base.Order

export Follower, inds, index, value, stored, each, sync

include("types.jl")
include("core.jl")
include("reshaped.jl")
include("sparse.jl")
include("sync_stored.jl")

end # module
