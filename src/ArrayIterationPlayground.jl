module ArrayIterationPlayground

import Base: getindex, setindex!, start, next, done, length, eachindex, show, parent, isless
using Base: ReshapedArray, ReshapedIndex, linearindexing, LinearFast, LinearSlow, LinearIndexing
using Base.PermutedDimsArrays: PermutedDimsArray

export inds, index, value, stored, each, sync

include("types.jl")
include("core.jl")
include("reshaped.jl")
include("sparse.jl")

end # module
