using Missings
"""
`FWF.parsefield{T}(io::IO, ::Type{T}, opt::FWF.Options=FWF.Options(), col=0)` => `Nullable{T}`

`io` is an `IO` type that is positioned at the first byte/character of a field
whitespace is ignored for numerial types, string trimming is configurable by options.
fields will be compared to the null list in options, any values found will result in a missing value
Parsing happens for Integrer, Float, Date, DateTime 

"""
function parsefield end

missingon(source::FWF.Source) = (source.options.missingcheck)
checkmissing(key::String, d::Dict{String, Missing}) = (in((key => missing), d)) 

function get_format(source::FWF.Source, col::Int) 
    !haskey(source.options.dateformats, col) && return nothing
    return source.options.dateformats[col]
end

# This main dispatch will always get called and dispatch to other methods
# We are going to pre-load whole lines and cache the results in the Source.
# Assume that every col==1 means load the next line
function parsefield(source::FWF.Source, ::Type{T}, col::Int) where {T}
    # Assume that every col==1 means load the next line
    col == 1 && (readsplitline!(source.currentline, source))
    
    if missingon(source) && checkmissing(source.currentline[col], source.options.missingvals)
        return missing
    end
    
    return parsefield(T, source.currentline[col], get_format(source, col))
end

# Batch of simple parsers to convert strings
null_to_missing(x) = isnull(x) ? missing : unsafe_get(x)
parsefield(::Type{Int}, string, format) = null_to_missing(tryparse(Int, string))
parsefield(::Type{Float64}, string, format) = null_to_missing(tryparse(Float64, string))
parsefield(::Type{String}, string, format) = string
parsefield(::Type{Date}, string, format) = null_to_missing(tryparse(Date, string, format))

# Generic fallback
function parsefield(T, string, format)
    return null_to_missing(tryparse(T, string))
end
