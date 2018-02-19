
"""
`FWF.parsefield{T}(source::FWF.Source, ::Type{T}, row::Int, col::Int)` => `Nullable{T}`
`FWF.parsecol{T}(source::FWF.Source, ::Type{T}, col::Int)` => `Nullable{T}`

`source` is the source to read from
`T` is the type of the column / field
`row` is the row that is being read, if applicable
`col` is the column that is being read.

whitespace is ignored for numerial types, string trimming is configurable by options.
If `checkfornulls` is set in `opt` fields will be compared to the null list in `opt`, any values found will result in a missing value
Parsing happens for Integrer, Float64, Date 
The parameter list without a row results in a whole column being streamed from the file.

"""
function parsefield end

missingon(source::FWF.Source) = (source.options.usemissings)
checkmissing(key::String, d::Dict{String, Missing}) = (haskey(d, key)) 

function get_format(source::FWF.Source, col::Int) 
    !haskey(source.options.dateformats, col) && return nothing
    return source.options.dateformats[col]
end

# This main dispatch will get called for field based parsing and dispatch to other methods
# We are going to pre-load whole lines and cache the results in the Source.
# Assume that every col==1 means load the next line
function parsefield(source::FWF.Source, ::Type{T}, row::Int, col::Int) where {T}
    # Assume that every col==1 means load the next line
    if !((col == source.lastcol+1) || (col == 1 && Data.size(source.schema)[2] == source.lastcol))
        throw(FWF.ParsingException("Out of order access col=$col lastcol=$(source.lastcol)"))
    end
    source.lastcol = col
    if col == 1
        readsplitline!(source.currentline, source)
    end
    
    if missingon(source) && checkmissing(source.currentline[col], source.options.missingvals)
        return missing
    end
    
    return parsefield(T, source.options.usemissings, source.currentline[col], get_format(source, col))
end

# This main dispatch will get called for column based parsing and dispatch to other methods
# This will allocate a vector to store a whole column of data and then parse a whole column
# at once out of the file by using row offsets.
# Assuming it is safe to use Data.size(source.schema) as we should always populate it.
# For now putting IO code here until I can figure out how to break it out into single field parsing...
# Pretty sure I can do that eventually.
function parsecol(source::FWF.Source, ::Type{T}, col::Int) where {T}
    source.malformed && throw(FWF.ParsingException("Column streaming not currently supported for files with malformed rows.  Please correct and re-run."))
    dim_r, dim_c = Data.size(source.schema)
    len_c = length(source.options.columnrange[col])
    len_r = last(last(source.options.columnrange))
    io = source.io
    v = Vector{T}(dim_r)
    buf = Vector{UInt8}(len_c)
    s = ""
    seek(io, source.datapos) # go to start, read a column
    for line in 1:dim_r
        seek(io, source.datapos + calc_offset(line, len_r, first(source.options.columnrange[col]), source.eolpad))
        readbytes!(io, buf, len_c)
        s = source.options.trimstrings ? strip(String(buf)) : String(buf)
        if missingon(source) && checkmissing(s, source.options.missingvals)
            v[line] = missing
        else
            v[line] = parsefield(T, source.options.usemissings, 
                        s, get_format(source, col))
        end
    end
    return v
end

function calc_offset(line, len_r, col, eolpad)
    if (line == 1) 
        return col - 1
    else
        return ((line-1) * (len_r + eolpad+1)) + col -1
    end
end
    # Batch of simple parsers to convert strings
    @static if VERSION >= v"0.7.0-DEV"
        null_to_missing(x, b, v) = x == nothing ? usemissing_or_val(b, v) : x
    else
        null_to_missing(x, b, v) = isnull(x) ? usemissing_or_val(b, v)  : unsafe_get(x)
    end
    usemissing_or_val(b, v) = b ? missing : v
    parsefield(::Type{Int}, usemissing::Bool, string::String, format) = 
        null_to_missing(tryparse(Int, string), usemissing, "")
    parsefield(::Type{Float64}, usemissing::Bool, string::String, format) = 
        null_to_missing(tryparse(Float64, string), usemissing, 0.)
    parsefield(::Type{String}, usemissing::Bool, string::String, format) = string
    parsefield(::Type{Date}, usemissing::Bool, string::String, format) = 
        null_to_missing(tryparse(Date, string, format), usemissing, Date())
    @inline parsefield(::Type{Union{Missing, T}}, usemissing::Bool, string::String, format) where {T} = 
        (parsefield(T, usemissing, string, format))
    @inline parsefield(::Type{Missing}, usemissing::Bool, string::String, format) = (missing)
# Generic fallback
function parsefield(T, usemissing::Bool, string::String, format)
    return null_to_missing(tryparse(T, string), usemissing, nothing)
end
