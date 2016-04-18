A = [1 5 -5;
     0 3 2]
B = sub(A, 1:2, 1:3)

@test each(index(A)) == eachindex(A) == 1:length(A)
@test each(index(B)) == CartesianRange((1:2, 1:3))
@test each(index(A, :, 1:2)) == CartesianRange((1:2, 1:2))
@test each(index(A, :, 2:3)) == CartesianRange((1:2, 2:3))
@test each(index(A, 1, :)) == CartesianRange((1, 1:3))

k = 0
for v in each(A)
    @test v == A[k+=1]
end

k = 0
for I in each(index(A))
    @test A[I] == A[k+=1]
end

k = 0
for I in eachindex(A)
    @test A[I] == A[k+=1]
end

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
