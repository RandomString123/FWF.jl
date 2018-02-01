
"""
`FWF.parsefield{T}(source::FWF.Source, ::Type{T}, opt::FWF.Options=FWF.Options(), col=0)` => `Nullable{T}`

`source` is the source to read from
whitespace is ignored for numerial types, string trimming is configurable by options.
If `checkfornulls` is set in `opt` fields will be compared to the null list in `opt`, any values found will result in a missing value
Parsing happens for Integrer, Float64, Date 

"""
function parsefield end

missingon(source::FWF.Source) = (source.options.missingcheck)
checkmissing(key::String, d::Dict{String, Missing}) = (haskey(d, key)) 

function get_format(source::FWF.Source, col::Int) 
    !haskey(source.options.dateformats, col) && return nothing
    return source.options.dateformats[col]
end

# This main dispatch will always get called and dispatch to other methods
# We are going to pre-load whole lines and cache the results in the Source.
# Assume that every col==1 means load the next line
function parsefield(source::FWF.Source, ::Type{T}, col::Int) where {T}
    # Assume that every col==1 means load the next line
    if !((col == source.lastcol+1) || (col == 1 && Data.size(source.schema)[2] == source.lastcol))
        throw(FWF.ParsingException("Out of order access col=$col lastcol=$(source.lastcol)"))
    end
    source.lastcol = col
    col == 1 && (readsplitline!(source.currentline, source))
    
    if missingon(source) && checkmissing(source.currentline[col], source.options.missingvals)
        return missing
    end
    
    return parsefield(T, source.currentline[col], get_format(source, col))
end

# Batch of simple parsers to convert strings
null_to_missing(x) = isnull(x) ? missing : unsafe_get(x)
parsefield(::Type{Int}, string::String, format) = null_to_missing(tryparse(Int, string))
parsefield(::Type{Float64}, string::String, format) = null_to_missing(tryparse(Float64, string))
parsefield(::Type{String}, string::String, format) = string
parsefield(::Type{Date}, string::String, format) = null_to_missing(tryparse(Date, string, format))

# Generic fallback
function parsefield(T, string::String, format)
    return null_to_missing(tryparse(T, string))
end
