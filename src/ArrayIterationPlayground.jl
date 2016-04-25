module ArrayIterationPlayground

import Base: getindex, setindex!, start, next, done, length, eachindex, show, parent
using Base: ReshapedArray, linearindexing, LinearFast, LinearSlow
using Base.PermutedDimsArrays: PermutedDimsArray

export inds, index, value, stored, each, sync

include("types.jl")
include("core.jl")
include("sparse.jl")

end # module
