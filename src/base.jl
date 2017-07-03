using .BigArrayIterators

function Base.ndims{D,T,N}(ba::BigArray{D,T,N})
    N
end

function Base.eltype{D, T, N}( ba::BigArray{D,T,N} )
    # @show T
    return T
end

function Base.size{D,T,N}( ba::BigArray{D,T,N} )
    # get size according to the keys
    ret = size( CartesianRange(ba) )
    return ret
end

function Base.size(ba::BigArray, i::Int)
    size(ba)[i]
end

function Base.show(ba::BigArray)
    display(ba)
end

function Base.display(ba::BigArray)
    for field in fieldnames(ba)
        println("$field: $(getfield(ba,field))")
    end
end

function Base.reshape{D,T,N}(ba::BigArray{D,T,N}, newShape)
    warn("reshape failed, the shape of bigarray is immutable!")
end

function Base.CartesianRange{D,T,N}( ba::BigArray{D,T,N} )
    warn("the size was computed according to the keys, which is a number of chunk sizes and is not accurate")
    ret = CartesianRange(
            CartesianIndex([typemax(Int) for i=1:N]...),
            CartesianIndex([0            for i=1:N]...))
    warn("boundingbox function abanduned due to the malfunction of keys in S3Dicts")
    return ret
end

function do_work_setindex{D,T,N,C}( chan::Channel{Tuple}, buf::Array{T,N}, ba::BigArray{D,T,N,C}, chk::Array{T,N} )
    for (blockID, chunkGlobalRange, globalRange, rangeInChunk, rangeInBuffer) in chan
        println("global range of chunk: $(string(chunkGlobalRange))")
        fill!(chk, convert(T, 0))
        delay = 0.05
        for t in 1:4
            try 
                data = ba.kvStore[ string(chunkGlobalRange) ]
                chk = reshape(reinterpret(T,decoding(data,C)), size(chk))
                chk[rangeInChunk] = buf[rangeInBuffer]
                ba.kvStore[ string(chunkGlobalRange) ] = encoding( chk, C)
                break
            catch e
                println("catch an error while saving in BigArray: $e")
                @show typeof(e)
                @show stacktrace()
                if t==4
                    println("rethrow the error: $e")
                    rethrow()
                end 
                sleep(delay*(0.8+(0.4*rand())))
                delay *= 10
                println("retry for the $(t)'s time: $(string(chunkGlobalRange))")
            end
        end
    end 
end 

"""
    put array in RAM to a BigArray
"""
function Base.setindex!{D,T,N,C}( ba::BigArray{D,T,N,C}, buf::Array{T,N},
                                idxes::Union{UnitRange, Int, Colon} ... )
    @assert eltype(ba) == T
    @assert ndims(ba) == N
    # @show idxes
    idxes = colon2unitRange(buf, idxes)
    baIter = BigArrayIterator(idxes, ba.chunkSize)
    chk = Array(T, ba.chunkSize)
    @sync begin 
        chan = Channel{Tuple}(4)
        @async begin 
            for iter in baIter
                put!(chan, iter)
            end
            close(chan)
        end
        for i in 1:4
            @async do_work_setindex(chan, buf, ba, chk)
        end
    end 
end 


function do_work_getindex!{D,T,N,C}(chan::Channel{Tuple}, buf::Array, ba::BigArray{D,T,N,C})
    for (blockId, chunkGlobalRange, globalRange, rangeInChunk, rangeInBuffer) in chan 
        # explicit error handling to deal with EOFError
        delay = 0.05
        for t in 1:4
            try 
                println("global range of chunk: $(string(chunkGlobalRange))") 
                v = ba.kvStore[string(chunkGlobalRange)]
                @assert isa(v, Array)
                chk = decoding(v, C)
                chk = reshape(reinterpret(T, chk), ba.chunkSize)
                buf[rangeInBuffer] = chk[rangeInChunk]
                break 
            catch e
                println("catch an error while getindex in BigArray: $e")
                if isa(e, NoSuchKeyException) || isa(e, KeyError)
                    println("no suck key in kvstore: $(e), code in BigArrays/src/base.jl")
                    @show typeof(e)
                    break
                else
                    if isa(e, EOFError)
                        println("get EOFError in bigarray getindex: $e")
                    end
                    if t==4
                        rethrow()
                    end
                    sleep(delay*(0.8+(0.4*rand())))
                    delay *= 10
                end
            end 
        end
    end
end

function Base.getindex{D,T,N,C}( ba::BigArray{D, T, N, C}, idxes::Union{UnitRange, Int}...)
    sz = map(length, idxes)
    buf = zeros(eltype(ba), sz)

    baIter = BigArrayIterator(idxes, ba.chunkSize, ba.offset)
    @sync begin
        chan = Channel{Tuple}(4)
        @async begin
            for iter in baIter
                put!(chan, iter)
            end
            close(chan)
        end
        # control the number of concurrent requests here
        for i in 1:4
            @async do_work_getindex!(chan, buf, ba)
        end
    end 
    # handle single element indexing, return the single value
    if length(buf) == 1
        return buf[1]
    else 
        # otherwise return array
        return buf
    end 
end

function get_chunk_size(ba::AbstractBigArray)
    ba.chunkSize
end
