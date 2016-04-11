A = sparse([1,4,3],[1,1,2],[0.2,0.4,0.6])
Af = full(A)

k = 0
for j = 1:2
    for i in eachindex(stored(A, :, j))
        @test A[i,j] == A.nzval[k+=1]
    end
end

k = 0
for j = 1:2
    for v in each(stored(A, :, j))
        @test v == A.nzval[k+=1]
    end
end

k = 0
for j = 1:2
    for i in each(index(A, :, j))
        @test A[i,j] == Af[k+=1]
    end
end

k = 0
for j = 1:2
    for v in each(A, :, j)
        @test v == Af[k+=1]
    end
end
