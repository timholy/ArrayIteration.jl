module ArrayIteration

import Base: getindex, setindex!, iterate, length, eachindex, show, parent, isless
using Base: ReshapedArray, ReshapedIndex, IndexStyle, IndexLinear, IndexCartesian
using Base: Slice, OneTo
using Base.PermutedDimsArrays: PermutedDimsArray
using Base.Order

using SparseArrays

export Follower, inds, index, value, stored, each, sync

include("types.jl")
include("core.jl")
include("reshaped.jl")
include("sparse.jl")
include("sync_stored.jl")

end # module
