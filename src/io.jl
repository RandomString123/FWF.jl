"""
    FWF.readsplitline!(vals::Vector{String}, source::FWF.Source)

Read a single line from a `FWF.Source` as a `Vector{String}` and
store the values in `vals`.
Fields are determined by the field widths stored in the source options
The contents of `vals` are replaced.
"""
# This function is pretty simple
# * Read line of input from the source
# * Ensure it meets specifications
# * Break it into chunks based on column widths

function readsplitline!(vals::Vector{String}, source::FWF.Source)
    return readsplitline!(vals, source.io, source.options.columnranges, source.options.trimstrings)
end

function readsplitline!(vals::Vector{String}, io::IO, columnwidths::Vector{UnitRange{Int}}, trim::Bool) 
    # Parameter validation
    ((columnwidths == nothing) || (isempty(columnwidths))) && throw(ArgumentError("No column widths provided"))
    eof(io) && (throw(ArgumentError("IO not available")))
    
    rowlength = last(last(columnwidths))
    # Read a line and validate
    line = readline(io)
    length(line) != rowlength && (throw(ParsingException("Invalid rowlength: "*string(length(line))))) 
    
    # Break it up into chunks
    for range in columnwidths
        str = line[range]
        trim && (str = strip(str))
        push!(vals, str)
    end
    return vals
end

"""
`CSV.read(fullpath::Union{AbstractString,IO}, sink::Type{T}=DataFrame, args...; kwargs...)` => `typeof(sink)`

`CSV.read(fullpath::Union{AbstractString,IO}, sink::Data.Sink; kwargs...)` => `Data.Sink`


parses a delimited file into a Julia structure (a DataFrame by default, but any valid `Data.Sink` may be requested).

Minimal error-reporting happens w/ `CSV.read` for performance reasons; for problematic csv files, try [`CSV.validate`](@ref) which takes exact same arguments as `CSV.read` and provides much more information for why reading the file failed.

Positional arguments:

* `fullpath`; can be a file name (string) or other `IO` instance
* `sink::Type{T}`; `DataFrame` by default, but may also be other `Data.Sink` types that support streaming via `Data.Field` interface; note that the method argument can be the *type* of `Data.Sink`, plus any required arguments the sink may need (`args...`).
                    or an already constructed `sink` may be passed (2nd method above)

Keyword Arguments:

* `delim::Union{Char,UInt8}`: how fields in the file are delimited; default `','`
* `quotechar::Union{Char,UInt8}`: the character that indicates a quoted field that may contain the `delim` or newlines; default `'"'`
* `escapechar::Union{Char,UInt8}`: the character that escapes a `quotechar` in a quoted field; default `'\\'`
* `null::String`: indicates how NULL values are represented in the dataset; default `""`
* `dateformat::Union{AbstractString,Dates.DateFormat}`: how dates/datetimes are represented in the dataset; default `Base.Dates.ISODateTimeFormat`
* `decimal::Union{Char,UInt8}`: character to recognize as the decimal point in a float number, e.g. `3.14` or `3,14`; default `'.'`
* `truestring`: string to represent `true::Bool` values in a csv file; default `"true"`. Note that `truestring` and `falsestring` cannot start with the same character.
* `falsestring`: string to represent `false::Bool` values in a csv file; default `"false"`
* `header`: column names can be provided manually as a complete Vector{String}, or as an Int/AbstractRange which indicates the row/rows that contain the column names
* `datarow::Int`: specifies the row on which the actual data starts in the file; by default, the data is expected on the next row after the header row(s); for a file without column names (header), specify `datarow=1`
* `types`: column types can be provided manually as a complete Vector{Type}, or in a Dict to reference individual columns by name or number
* `nullable::Bool`: indicates whether values can be nullable or not; `true` by default. If set to `false` and missing values are encountered, a `Data.NullException` will be thrown
* `footerskip::Int`: indicates the number of rows to skip at the end of the file
* `rows_for_type_detect::Int=100`: indicates how many rows should be read to infer the types of columns
* `rows::Int`: indicates the total number of rows to read from the file; by default the file is pre-parsed to count the # of rows; `-1` can be passed to skip a full-file scan, but the `Data.Sink` must be set up to account for a potentially unknown # of rows
* `use_mmap::Bool=true`: whether the underlying file will be mmapped or not while parsing; note that on Windows machines, the underlying file will not be "deletable" until Julia GC has run (can be run manually via `gc()`) due to the use of a finalizer when reading the file.
* `append::Bool=false`: if the `sink` argument provided is an existing table, `append=true` will append the source's data to the existing data instead of doing a full replace
* `transforms::Dict{Union{String,Int},Function}`: a Dict of transforms to apply to values as they are parsed. Note that a column can be specified by either number or column name.
* `transpose::Bool=false`: when reading the underlying csv data, rows should be treated as columns and columns as rows, thus the resulting dataset will be the "transpose" of the actual csv data.
* `categorical::Bool=true`: read string column as a `CategoricalArray` ([ref](https://github.com/JuliaData/CategoricalArrays.jl)), as long as the % of unique values seen during type detection is less than 67%. This will dramatically reduce memory use in cases where the number of unique values is small.
* `weakrefstrings::Bool=true`: whether to use [`WeakRefStrings`](https://github.com/quinnj/WeakRefStrings.jl) package to speed up file parsing; can only be `=true` for the `Sink` objects that support `WeakRefStringArray` columns. Note that `WeakRefStringArray` still returns regular `String` elements.

Example usage:
```
julia> dt = CSV.read("bids.csv")
7656334×9 DataFrames.DataFrame
│ Row     │ bid_id  │ bidder_id                               │ auction │ merchandise      │ device      │
├─────────┼─────────┼─────────────────────────────────────────┼─────────┼──────────────────┼─────────────┤
│ 1       │ 0       │ "8dac2b259fd1c6d1120e519fb1ac14fbqvax8" │ "ewmzr" │ "jewelry"        │ "phone0"    │
│ 2       │ 1       │ "668d393e858e8126275433046bbd35c6tywop" │ "aeqok" │ "furniture"      │ "phone1"    │
│ 3       │ 2       │ "aa5f360084278b35d746fa6af3a7a1a5ra3xe" │ "wa00e" │ "home goods"     │ "phone2"    │
...
```

Other example invocations may include:
```julia
# read in a tab-delimited file
CSV.read(file; delim='\t')

# read in a comma-delimited file with null values represented as '\\N', such as a MySQL export
CSV.read(file; null="\\N")

# read a csv file that happens to have column names in the first column, and grouped data in rows instead of columns
CSV.read(file; transpose=true)

# manually provided column names; must match # of columns of data in file
# this assumes there is no header row in the file itself, so data parsing will start at the very beginning of the file
CSV.read(file; header=["col1", "col2", "col3"])

# manually provided column names, even though the file itself has column names on the first row
# `datarow` is specified to ensure data parsing occurs at correct location
CSV.read(file; header=["col1", "col2", "col3"], datarow=2)

# types provided manually; as a vector, must match length of columns in actual data
CSV.read(file; types=[Int, Int, Float64])

# types provided manually; as a Dict, can specify columns by # or column name
CSV.read(file; types=Dict(3=>Float64, 6=>String))
CSV.read(file; types=Dict("col3"=>Float64, "col6"=>String))

# manually provided # of rows; if known beforehand, this will improve parsing speed
# this is also a way to limit the # of rows to be read in a file if only a sample is needed
CSV.read(file; rows=10000)

# for data files, `file` and `file2`, with the same structure, read both into a single DataFrame
# note that `df` is used as a 2nd argument in the 2nd call to `CSV.read` and the keyword argument
# `append=true` is passed
df = CSV.read(file)
df = CSV.read(file2, df; append=true)

# manually construct a `CSV.Source` once, then stream its data to both a DataFrame
# and SQLite table `sqlite_table` in the SQLite database `db`
# note the use of `CSV.reset!` to ensure the `source` can be streamed from again
source = CSV.Source(file)
df1 = CSV.read(source, DataFrame)
CSV.reset!(source)
db = SQLite.DB()
sq1 = CSV.read(source, SQLite.Sink, db, "sqlite_table")
```
"""
function read end

function read(fullpath::Union{AbstractString,IO}, columnwidths::Union{Vector{UnitRange{Int}}, Vector{Int}}, sink::Type=DataFrame, args...; append::Bool=false, transforms::Dict=Dict{Int,Function}(), transpose::Bool=false, kwargs...)
    source =  Source(fullpath, columnwidths; kwargs...)
    sink = Data.stream!(source, sink, args...; append=append, transforms=transforms)
    return Data.close!(sink)
end

function read(fullpath::Union{AbstractString,IO}, columnwidths::Union{Vector{UnitRange{Int}}, Vector{Int}}, sink::T; append::Bool=false, transforms::Dict=Dict{Int,Function}(), transpose::Bool=false, kwargs...) where {T}
    source = Source(fullpath, columnwidths; kwargs...)
    sink = Data.stream!(source, sink; append=append, transforms=transforms)
    return Data.close!(sink)
end

read(source::FWF.Source, sink=DataFrame, args...; append::Bool=false, transforms::Dict=Dict{Int,Function}()) = (sink = Data.stream!(source, sink, args...; append=append, transforms=transforms); return Data.close!(sink))
read(source::FWF.Source, sink::T; append::Bool=false, transforms::Dict=Dict{Int,Function}()) where {T} = (sink = Data.stream!(source, sink; append=append, transforms=transforms); return Data.close!(sink))
#read(source::CSV.TransposedSource, sink=DataFrame, args...; append::Bool=false, transforms::Dict=Dict{Int,Function}()) = (sink = Data.stream!(source, sink, args...; append=append, transforms=transforms); return Data.close!(sink))
#read(source::CSV.TransposedSource, sink::T; append::Bool=false, transforms::Dict=Dict{Int,Function}()) where {T} = (sink = Data.stream!(source, sink; append=append, transforms=transforms); return Data.close!(sink))
