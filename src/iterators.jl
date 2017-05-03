module BigArrayIterators

using ..BigArrays

export BigArrayIterator

immutable BigArrayIterator{N}
    globalRange     ::CartesianRange{CartesianIndex{N}}
    chunkSize       ::NTuple{N}
    chunkIDRange    ::CartesianRange{CartesianIndex{N}}
    offset          ::CartesianIndex{N}
end

function BigArrayIterator{N}( globalRange::CartesianRange{CartesianIndex{N}},
                              chunkSize::NTuple{N},
                              offset::CartesianIndex{N} )
    chunkIDStart = CartesianIndex(index2chunkid( globalRange.start, chunkSize, offset ))
    chunkIDStop  = CartesianIndex(index2chunkid( globalRange.stop,  chunkSize, offset ))
    chunkIDRange = CartesianRange(chunkIDStart, chunkIDStop)
    BigArrayIterator( globalRange, chunkSize, chunkIDRange, offset )
end

function BigArrayIterator{N}( idxes::Tuple,
                              chunkSize::NTuple{N})
    globalRange = CartesianRange(idxes)
    offset = CartesianIndex{N}() - 1
    BigArrayIterator( globalRange, chunkSize, offset )
end

function BigArrayIterator{N}( idxes::Tuple,
                              chunkSize::NTuple{N},
                              offset::CartesianIndex)
    globalRange = CartesianRange(idxes)
    BigArrayIterator( globalRange, chunkSize, offset )
end

function BigArrayIterator( ba::AbstractBigArray )
    BigArrayIterator( ba.globalRange, ba.chunkSize )
end

function Base.length( iter::BigArrayIterator )
    length( iter.globalRange )
end

function Base.eltype( iter::BigArrayIterator )
    eltype( iter.globalRange )
end

"""
the state is a tuple {chunkID, and the dimension that is increasing}
"""
function Base.start( iter::BigArrayIterator )
    iter.chunkIDRange.start
end

"""
    Base.next( iter::BigArrayIterator, state::CartesianRange )

increase start coordinate following the column-order.
"""
function Base.next{N}(  iter    ::BigArrayIterator{N},
                        state   ::CartesianIndex{N} )
    chunkIDIndex, state = next(iter.chunkIDRange, state)
    chunkID = tuple(chunkIDIndex.I...)

    # get current global range in this chunk
    start = CartesianIndex(( map((x,y,z,o)->max((x-1)*y+1+o, z), chunkID,
                            iter.chunkSize, iter.globalRange.start,
                            iter.offset )...))
    stop  = CartesianIndex(( map((x,y,z,o)->min(x*y+o, z),       chunkID,
                            iter.chunkSize, iter.globalRange.stop,
                            iter.offset )...))
    # the global range of the cutout in this chunk
    globalRange = CartesianRange(start, stop)
    @show globalRange
    # the range inside this chunk
    rangeInChunk  = global_range2chunk_range( globalRange, iter.chunkSize, iter.offset)
    @show rangeInChunk 
    # the range inside the buffer
    rangeInBuffer = global_range2buffer_range(globalRange, iter.globalRange)
    @show rangeInBuffer
    # the global range of this chunk
    chunkGlobalRange = chunkid2global_range( chunkID, iter.chunkSize, iter.offset )
    @show chunkGlobalRange
    return (chunkID, chunkGlobalRange, globalRange, rangeInChunk, rangeInBuffer), state
end

"""
    Base.done( iter::BigArrayIterator,  state::CartesianRange )

if all the axeses were saturated, stop the iteration.
"""
function Base.done{N}(  iter::BigArrayIterator{N},
                        state::CartesianIndex{N})
    done(iter.chunkIDRange, state)
end

end # end of module
