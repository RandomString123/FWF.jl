
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
checkmissing(key::String, d::Set{String}) = key in d

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
   
    tmp = source.currentline[col]
    ismissing(tmp) && return missing
    # We know ref is a string
    ref::String = tmp
    if missingon(source) && checkmissing(ref, source.options.missingvals)
        return missing
    end
    
    return parsefield(T, source.options.usemissings, ref, get_format(source, col))
end

# Batch of simple parsers to convert strings
usemissing_or_val(b, v) = b ? missing : v
if VERSION >= v"0.7.0-DEV"
    null_to_missing(x, b, v) = x == nothing ? usemissing_or_val(b, v) : x
else
    null_to_missing(x, b, v) = isnull(x) ? usemissing_or_val(b, v)  : unsafe_get(x)
end

parsefield(::Type{Int}, usemissing::Bool, string::String, format) = 
    null_to_missing(tryparse(Int, string), usemissing, 0)
parsefield(::Type{Float64}, usemissing::Bool, string::String, format) = 
    null_to_missing(tryparse(Float64, string), usemissing, 0.)
parsefield(::Type{String}, usemissing::Bool, string::String, format) = string
parsefield(::Type{Date}, usemissing::Bool, string::String, format) = 
    null_to_missing(tryparse(Date, string, format), usemissing, Date())
parsefield(::Type{Union{Missing, T}}, usemissing::Bool, string::String, format) where {T} = 
    (parsefield(T, usemissing, string, format))
parsefield(::Type{Missing}, usemissing::Bool, string::String, format) = (missing)

# Generic fallback
function parsefield(T, usemissing::Bool, string::String, format)
    return null_to_missing(tryparse(T, string), usemissing, nothing)
end
