#function sync{AA,I}(FA::Follower, B::ArrayIndexingWrapper{AA,I,true})
function sync(FA::Follower, B)
    A = parent(FA)
    checksame_inds(A, B)
    iter, Bind, Bfunc = syncable(B)
    SyncedIterator(each(iter), (stripwrapper(A), Bind), (synciterfunc(A, iter), Bfunc))
end

# value-iterator
syncable(A) = index(A), stripwrapper(A), (A, i) -> (@inbounds ret = A[i]; ret)
# syncable{AA,I}(A::ArrayIndexingWrapper{AA,I,false}) = A, parent(A), (A, i) -> (println("2"); @inbounds ret = A[i]; ret)
# index-iterator
syncable(A::ArrayIndexingWrapper{AA,I,true}) where {AA,I} = A, parent(A), (A, i) -> i

synciterfunc(A, B) = _synciterfunc(A, extent_dims(B))
# value-iterator
_synciterfunc(A, d::Tuple{Int}) = (A, i) -> A[i[d[1]]]
# index-iterator
_synciterfunc(A::ArrayIndexingWrapper{AA,I,true}, d::Tuple{Int}) where {AA,I} = (A, i) -> i[d[1]]
