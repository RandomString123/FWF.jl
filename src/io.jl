"""
    FWF.readsplitline!(vals::Vector{String}, source::FWF.Source)
    FWF.readsplitline!(vals::Vector{String}, io::IO, columnwidths::Vector{UnitRange{Int}}, trim::Bool, skiponerror::Bool)

Read next line from a `FWF.Source` or `IO` as a `Vector{String}` and
store the values in `vals`.
Fields are determined by the field widths stored in the `source` options or `columnwidths`
Fields will be trimed if `trim` is true
Row or rows will be skipped if there is an error found if `skiponerror` is true
The contents of `vals` are replaced.
"""
# This function is pretty simple
# * Read line of input from the source
# * Ensure it meets specifications
# * Break it into chunks based on column widths

function readsplitline!(vals::Vector{String}, source::FWF.Source)
    return readsplitline!(vals, source.io, source.options.columnrange, source.options.trimstrings, source.options.skiponerror)
end

function readsplitline!(vals::Vector{String}, io::IO, columnwidths::Vector{UnitRange{Int}}, trim::Bool=true, skiponerror=true) 
    empty!(vals)
    # Parameter validation
    ((columnwidths == nothing) || (isempty(columnwidths))) && throw(ArgumentError("No column widths provided"))
    eof(io) && (throw(ArgumentError("IO not available")))
    
    rowlength = last(last(columnwidths))
    # Read a line and validate
    test = true
    line = ""

    while test 
        eof(io) && (throw(ArgumentError("Unable to find next valid line")))
        line = readline(io)
        if (length(line) != rowlength)
            !skiponerror && throw(ParsingException("Invalid length line: "*string(length(line))))
            skiponerror && println(STDOUT, "Invalid length line:", line)
        else
            test = false
        end
    end

    # Break it up into chunks
    for range in columnwidths
        str = line[range]
        trim && (str = strip(str))
        push!(vals, str)
    end
    return vals
end

"""
`FWF.read(fullpath::Union{AbstractString,IO}, columnwidths::Union{Vector{UnitRange{Int}}, Vector{Int}}, sink::Type{T}=DataFrame, args...; kwargs...)` => `typeof(sink)`

`FWF.read(fullpath::Union{AbstractString,IO}, columnwidths::Union{Vector{UnitRange{Int}}, Vector{Int}}, sink::Data.Sink; kwargs...)` => `Data.Sink`


parses a fixed width file into a Julia structure (a DataFrame by default, but any valid `Data.Sink` may be requested).


Positional arguments:

* `fullpath`; can be a file name (string) or other `IO` instance
* `columnwidths`; can be a vector of integers or consecutive unit ranges that represents the column widths
                    examples: [4,4,8] or [1:4,5:8, 9:16]
* `sink::Type{T}`; `DataFrame` by default, but may also be other `Data.Sink` types that support streaming via `Data.Field` interface; note that the method argument can be the *type* of `Data.Sink`, plus any required arguments the sink may need (`args...`).
                    or an already constructed `sink` may be passed (2nd method above)

Keyword Arguments:

* `usemissings::Bool`: whether to use missings, all fields will be unioned with Missing; default = true
                        if not set default values of 0, date() and "" will be used for missing values
* `trimstrings::Bool`: trim whitespace from all strings; default = true
* `skiponerror::Bool`: if an invalid length line is encountered will skip to the next; default = true
* `use_mmap::Bool=true`: whether the underlying file will be mmapped or not while parsing; note that on Windows machines, the underlying file will not be "deletable" until Julia GC has run (can be run manually via `gc()`) due to the use of a finalizer when reading the file.
* `skip::Int`: number of rows at start of file to skip; default = 0
* `rows::Int`: maximum number of rows to read from file; default = 0 (whole file)
* `types`: a vector of how to parse each column. (String, Int, Float64, Missing) are valid types, missing will convert whole comumn to `missing`. Pass in the format for Date columns as DateFormat("")
            example: [String, Int, DateFormat("mmddyyyy")]
* `header`: column names can be provided as a Vector{String} or parameter can be set to `true` to use the first row as values or `false` to auto-generate names 
* `missings`: a Vector{String} that represents all values that should be converted to missing; example: ["***", "NA", "NULL", "####"]
* `append::Bool=false`: if the `sink` argument provided is an existing table, `append=true` will append the source's data to the existing data instead of doing a full replace
* `transforms::Dict{Union{String,Int},Function}`: a Dict of transforms to apply to values as they are parsed. Note that a column can be specified by either number or column name.

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

#read(source::FWF.Source, columnwidths::Union{Vector{UnitRange{Int}}, sink=DataFrame, args...; append::Bool=false, transforms::Dict=Dict{Int,Function}()) = (sink = Data.stream!(source, sink, args...; append=append, transforms=transforms); return Data.close!(sink))
#read(source::FWF.Source, columnwidths::Union{Vector{UnitRange{Int}}, sink::T; append::Bool=false, transforms::Dict=Dict{Int,Function}()) where {T} = (sink = Data.stream!(source, sink; append=append, transforms=transforms); return Data.close!(sink))
#read(source::CSV.TransposedSource, sink=DataFrame, args...; append::Bool=false, transforms::Dict=Dict{Int,Function}()) = (sink = Data.stream!(source, sink, args...; append=append, transforms=transforms); return Data.close!(sink))
#read(source::CSV.TransposedSource, sink::T; append::Bool=false, transforms::Dict=Dict{Int,Function}()) where {T} = (sink = Data.stream!(source, sink; append=append, transforms=transforms); return Data.close!(sink))
