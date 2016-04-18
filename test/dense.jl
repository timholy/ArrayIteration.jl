A = [1 5 -5;
     0 3 2]

@test each(index(A)) == CartesianRange((1:2, 1:3))
@test each(index(A, :, 1:2)) == CartesianRange((1:2, 1:2))
@test each(index(A, :, 2:3)) == CartesianRange((1:2, 2:3))

k = 0
for j in inds(A, 2)
    for v in each(A, :, j)
        @test v == A[k+=1]
    end
end

k = 0
for j in inds(A, 2)
    for I in each(index(A, :, j))
        @test A[I] == A[k+=1]
    end
end

k = 0
for j in inds(A, 2)
    for I in eachindex(stored(A, :, j))
        @test A[I] == A[k+=1]
    end
end

k = 0
for j in inds(A, 2)
    for v in each(stored(A, :, j))
        @test v == A[k+=1]
    end
end
