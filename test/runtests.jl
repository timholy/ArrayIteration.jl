using ArrayIterationPlayground
using Base.Test

A = zeros(2,3)
@test inds(A, 1) == 1:2
@test inds(A, 2) == 1:3
@test inds(A, 3) == 1:1
@test inds(A) == (1:2, 1:3)

io = IOBuffer()
show(io, index(A))
@test takebuf_string(io) == "iteration hint over indexes of a "*summary(A)*" over the region (Colon(),Colon())"
io = IOBuffer()
show(io, index(A, :, 2:3))
@test takebuf_string(io) == "iteration hint over indexes of a "*summary(A)*" over the region (Colon(),2:3)"
io = IOBuffer()
show(io, stored(A, 1, 2:3))
@test takebuf_string(io) == "iteration hint over stored values of a "*summary(A)*" over the region (1,2:3)"
io = IOBuffer()
show(io, index(stored(A, 1:2, :)))
@test takebuf_string(io) == "iteration hint over indexes of stored values of a "*summary(A)*" over the region (1:2,Colon())"
io = IOBuffer()
show(io, stored(index(A, 1:2, :)))
@test takebuf_string(io) == "iteration hint over indexes of stored values of a "*summary(A)*" over the region (1:2,Colon())"

include("dense.jl")
include("sparse.jl")
