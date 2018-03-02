getline(source::IO, ::UInt8) = Vector{UInt8}(readline(source))
getline(source::IO, ::Base.Chars) = readline(source)

"""
`scan(source, blank; skip, nrow)

Reads fixed wdith format file or stream `source`.
Returns `Vector{UnitRange{Int}}` with autotetected fields in `source`.
Detects only fields that exist in all checked lines.

Parameters:
* `source::Union{IO, AbstractString}`: stream or filename to read from
* `blank::Union{Base.Chars, UInt8}=Base._default_delims`: which characters are considered non-data
* `skip::Int=0`: number of lines to skip at the beginning of the file
* `nrow::Int=0`: number of rows containing data to read (possibly including header);
  `0` means to read all data

  If `blank` is `UInt8` then byte indexing is used, otherwise character indexinx is assumed
"""
function scan(source::IO, blank::Union{Base.Chars, UInt8}=Base._default_delims;
              skip::Int=0, nrow::Int=0)
    for i in 1:skip
        line = readline(source)
    end

    allblank = Int[]
    maxwidth = 0
    firstline = true
    row = 0
    while (row < nrow || nrow == 0) && !eof(source)
        line = getline(source, blank)
        isempty(line) && eof(source) && break
        thisblank = Int[]
        for (i, c) in enumerate(line)
            c in blank && push!(thisblank, i)
        end
        if firstline
            allblank = thisblank
            firstline = false
        else
            allblank = intersect(thisblank, allblank)
        end
        maxwidth = max(maxwidth, length(line))
        row += 1
    end
    # if character at maxwidth character index was not blank
    # add a virtual blank at maxwidth+1
    (isempty(allblank) || allblank[end] < maxwidth) && push!(allblank, maxwidth+1)
    last_blank = 0
    range = UnitRange{Int}[]
    maxwidth == 0 && return range
    for this_blank in allblank
        # do not create zero width columns
        if this_blank > last_blank + 1
            push!(range, (last_blank+1):(this_blank-1))
        end
        last_blank = this_blank
    end
    range
end

function scan(source::AbstractString, blank::Union{Base.Chars, UInt8}=Base._default_delims;
              skip::Int=0, nrow::Int=0)
    open(source) do handle
        scan(handle, blank, skip=skip, nrow=nrow)
    end
end

