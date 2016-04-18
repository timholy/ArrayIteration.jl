using ArrayIterationPlayground
using Base.Test

A = zeros(2,3)
@test inds(A, 1) == 1:2
@test inds(A, 2) == 1:3
@test inds(A, 3) == 1:1
@test inds(A) == (1:2, 1:3)

include("dense.jl")
include("sparse.jl")
