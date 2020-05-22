# This file contains tests of internal mechanisms that are probably
# not of user-level interest.  One consequence is that it's OK to
# replace/break these tests if you're redesigning the internal API
# (as long as you preserve the same overall behavior).

A = rand(3,4)
AI.checksame_inds(A, A)
@test_throws DimensionMismatch AI.checksame_inds(A, A')
@test isa(@inferred(AI.storageorder(A)), AI.FirstToLast)
R = reshape(A, (2,3,2))
@test isa(@inferred(AI.storageorder(R)), AI.FirstToLast)
S = view(A, 1:3, 1:4)
R = reshape(S, (2,3,2))
@test isa(@inferred(AI.storageorder(R)), AI.FirstToLast)
B = PermutedDimsArray(A, [2,1])
@test isa(@inferred(AI.storageorder(B)), AI.OtherOrder{(2,1)})
R = reshape(B, (2,2,3))
@test isa(@inferred(AI.storageorder(R)), AI.NoOrder)

@test @inferred(AI.contiguous_index((:, :))) == AI.Contiguous()
@test @inferred(AI.contiguous_index((:, 3))) == AI.Contiguous()
@test @inferred(AI.contiguous_index((3, :))) == AI.NonContiguous()
@test @inferred(AI.contiguous_index((3, 3))) == AI.Contiguous()
@test @inferred(AI.contiguous_index((:, :, 3))  ) == AI.Contiguous()
@test @inferred(AI.contiguous_index((:, :, 1:2))) == AI.Contiguous()
@test @inferred(AI.contiguous_index((:, 3, :))  ) == AI.NonContiguous()
@test @inferred(AI.contiguous_index((:, 3, 1:2))) == AI.NonContiguous()

@test isless(CartesianIndex((1,1)), CartesianIndex((2,1)))
@test isless(CartesianIndex((1,1)), CartesianIndex((1,2)))
@test isless(CartesianIndex((2,1)), CartesianIndex((1,2)))
@test !isless(CartesianIndex((1,2)), CartesianIndex((2,1)))

A = sparse([1,4,3],[1,1,2],[0.2,0.4,0.6])
@test isa(A, AI.ContiguousCSC)
@test isa(view(A, :, 1), AI.ContiguousCSC)
@test isa(view(A, 1:2, 2), AI.ContiguousCSC)
@test isa(view(A, :, 1:2), AI.ContiguousCSC)
@test !isa(view(A, 1:2, 1:2), AI.ContiguousCSC)
@test !isa(view(A, :, [1,2]), AI.ContiguousCSC)
@test !isa(view(A, [1,2], 1), AI.ContiguousCSC)
