
"""
    row_countlines(io::IO)

    Count number of rows in a file, also deteremines EOL character/padding from first line.
    Test last line of file to see if it is 0 or len bytes
"""
# To support bytes or characters this no longer does malformed testing
function row_countlines(io::IO)
    rows = 0
    # EOL detection, if we don't have an EoL doesn't matter
    start_pos = position(io)
    line = readline(io, chomp=false)
    eolpad = (eof(io) || length(line) < 2 || (line[end-1] != '\r')) ? 0 : 1
    seek(io, start_pos)
    rows = mod_countlines(io)
    return (rows, eolpad)
end

# version of countlines() that checks last line for non-empty.
function mod_countlines(io::IO) 
    b=[UInt8(0)]::Vector{UInt8}
    eof(io) && return 0
    l = countlines(io)
    readbytes!(skip(io, -1), b, 1)
    (b[1] == UInt8('\n')) ? l : l+1
end


"""
    FWF.readsplitline!(vals::Vector{Union{Missing,String}}, source::FWF.Source)
    FWF.readsplitline!(vals::Vector{Union{Missing,String}}, io::IO, columnwidths::Vector{UnitRange{Int}}, trim::Bool, errorlevel::Symbol)

Read next line from a `FWF.Source` or `IO` as a `Vector{String}` and
store the values in `vals`.
Fields are determined by the field widths stored in the `source` options or `columnwidths`
Fields will be trimed if `trim` is true
Row or rows will be skipped if there is an error found if `errorlevel` is `:skip`
and as much as possible is parsed if it is `:parse`.
The contents of `vals` are replaced.
Returns length of line read in bytes or characters following `unitbytes` keyword argument.
"""
# This function is pretty simple
# * Read line of input from the source
# * Ensure it meets specifications
# * Break it into chunks based on column widths

function readsplitline!(vals::Vector{Union{Missing,String}}, source::FWF.Source)
    line_len = readsplitline!(vals, source.io, source.options.columnrange,
                              source.options.trimstrings, source.options.unitbytes,
                              source.options.errorlevel)
    if source.line_len == -1
        source.line_len = line_len
    elseif source.line_len != line_len
        println(STDERR, "Inconsistent line lengths. Current $(line_len) and first valid length was $(source.line_len)")
    end
    return line_len
end

function readsplitline!(vals::Vector{Union{Missing,String}}, io::IO, columnwidths::Vector{UnitRange{Int}}, trim::Bool=true, unitbytes=true, errorlevel=:parse)
    empty!(vals)
    # Parameter validation
    ((columnwidths == nothing) || (isempty(columnwidths))) && throw(ArgumentError("No column widths provided"))
    eof(io) && (throw(ArgumentError("IO not available")))
    
    our_length = unitbytes ? sizeof : length
    
    rowlength = last(last(columnwidths))
    # Read a line and validate
    test = true
    line = ""
    line_len::Int = -1

    while test
        eof(io) && (throw(ArgumentError("Unable to find next valid line")))
        line = readline(io)
        line_len = our_length(line)
        # we do not care what is in the line beyond rowlength
        if line_len < rowlength
            !(errorlevel in (:parse, :skip)) && throw(ParsingException("Invalid length line: "*string(our_length(line))))
            println(STDERR, "Invalid length line($(our_length(line))):", line)
            if errorlevel == :parse
                test = false
            end
        else
            test = false
        end
    end

    chr = 0
    ind = 0
    # Break it up into chunks
    for range in columnwidths
        if errorlevel == :parse && first(range) > line_len
            push!(vals, missing)
            continue
        end
        if unitbytes || isascii(line)
            # Julia 0.7 is more strict about parsing string ranges
            # below will fail if first(range) is not a valid index into line
            # TODO: simplify when only Julia 0.7 or higher is supported
            str = line[first(range):prevind(line, last(range)+1)]
        else
            # TODO: this code will be simpler when only Julia 0.7 or higher is supported
            while chr < first(range)
                ind = nextind(line, ind)
                chr += 1
            end
            ind_start = ind
            while chr < last(range)
                ind = nextind(line, ind)
                chr += 1
            end
            if errorlevel == :parse
                # TODO: in Julia 1.0 we will have to replace endof
                str = line[ind_start:min(ind, endof(line))]
            else
                str = line[ind_start:ind]
            end
        end
        # strip returns SubString in Julia 0.7 or higher
        push!(vals, trim ? String(strip(str)) : str)
    end
    return line_len
end

"""
`FWF.read(fullpath::Union{AbstractString,IO}, columnwidths::Union{Vector{UnitRange{Int}}, Vector{Int}}, sink::Type{T}=DataFrame, args...; kwargs...)` => `typeof(sink)`

`FWF.read(fullpath::Union{AbstractString,IO}, columnwidths::Union{Vector{UnitRange{Int}}, Vector{Int}}, sink::Data.Sink; kwargs...)` => `Data.Sink`


parses a fixed width file into a Julia structure (a DataFrame by default, but any valid `Data.Sink` may be requested).


Positional arguments:

* `fullpath`; can be a file name (string) or other `IO` instance
* `columnwidths`; can be a vector of integers or consecutive unit ranges that represents the column widths
  examples: [4,4,8] or [1:4,5:8, 9:16]; ranges may be discontinous, e.g. [1:2, 5:10].
  Widths are interpreted either in bytes or characters as defined by `unitbytes` keyword argument
  Each valid line in the file must have its width at least equal to width implied by passed `columnwidths`
  (if it is wider it is silently ignored).
* `sink::Type{T}`; `DataFrame` by default, but may also be other `Data.Sink` types that support streaming via
  `Data.Field` interface; note that the method argument can be the *type* of `Data.Sink`, plus any required
  arguments the sink may need (`args...`) or an already constructed `sink` may be passed (2nd method above)

Keyword Arguments:

* `unitbytes::Bool`: whether to treat field ranges in bytes or characters; default = true (bytes)
* `usemissings::Bool`: whether to use missings, all fields will be unioned with Missing; default = true
                        if not set default values of 0, Date() and "" will be used for missing values
* `trimstrings::Bool`: trim whitespace from all strings; default = true
* `errorlevel`  : if `:parse` then as much as possible is parsed and missing data is replaced by `missing`;
                if `:skip` then malformed line is skipped on error;
                if `:error` then an exception is thrown on error; default `:parse`
* `use_mmap::Bool=true`: whether the underlying file will be mmapped or not while parsing; note that on Windows machines, the underlying file will not be "deletable" until Julia GC has run (can be run manually via `gc()`) due to the use of a finalizer when reading the file.
* `skip::Int`: number of rows at start of file to skip; default = 0
* `rows::Int`: maximum number of rows to read from file; default = 0 (whole file)
* `types`: a vector of how to parse each column. (String, Int, Float64, Missing) are valid types, missing will convert whole comumn to `missing`. Pass in the format for Date columns as DateFormat("")
            example: [String, Int, DateFormat("mmddyyyy")]
* `header`: column names can be provided as a Vector{String} or parameter can be set to `true` to use the first row as values or `false` to auto-generate names 
* `missings`: a Vector{String} that represents all values that should be converted to missing; example: ["***", "NA", "NULL", "####"]
* `append::Bool=false`: if the `sink` argument provided is an existing table, `append=true` will append the source's data to the existing data instead of doing a full replace
* `transforms::Dict{Union{String,Int},Function}`: a Dict of transforms to apply to values as they are parsed. Note that a column can be specified by either number or column name.

Simple example using inline text:
```
julia> FWF.read(IOBuffer("abc12310102017\ndef45610112017\n"), [3,3,8], types=[String,Int,DateFormat("mmddyyyy")])
```
Example usage from test dataset:
```
# Setup data frame with control information:
julia> format = DataFrame(["PSEUDO-ID" 9 Int;
    "EMPLOYEE_NAME" 23 Missing;
    "FILE_DATE" 8  DateFormat("yyyymmdd");
    "AGENCY" 2 String;
    "SUB_AGENCY" 2 String;
    "DUTY_STATION" 9 String;
    "AGE" 6 String;
    "EDUCATION_LEVEL" 2 String;
    "PAY_PLAN" 2 String;
    "GRADE" 2 String;
    "LOS_LEVEL" 6 String;
    "OCCUPATION" 4 String;
    "OCCUPATIONAL_CATEGORY" 1 String;
    "ADJUSTED_BASIC_PAY" 6 Int;
    "SUPERVISORY_STATUS" 1 String;
    "TYPE_OF_APPOINTMENT" 2 String;
    "WORK_SCHEDULE" 1 String;
    "NSFTP_IND"  1 String])

#Setup NA values
julia> strrep(s::String, r::UnitRange) = [repeat(s, n) for n in r]
julia> naValues = vcat(strrep("*", 1:23), strrep("#", 1:23), "NAME WITHHELD BY AGENCY", "NAME WITHHELD BY OPM", "NAME UNKNOWN", "UNSP", "<NA>", "000000", "999999", "")


julia> dt = FWF.read("sal.txt", convert(Array{Int},format[:x2]), 
        header=convert(Array{String}, format[:x1]), types=convert(Array{Union{Type, DateFormat}},format[:x3]), 
        missings=naValues)
200000×18 DataFrames.DataFrame. Omitted printing of 8 columns
│ Row    │ PSEUDO-ID │ EMPLOYEE_NAME │ FILE_DATE  │ AGENCY │ SUB_AGENCY │ DUTY_STATION │ AGE   │ EDUCATION_LEVEL │ PAY_PLAN │ GRADE │
├────────┼───────────┼───────────────┼────────────┼────────┼────────────┼──────────────┼───────┼─────────────────┼──────────┼───────┤
│ 1      │ 278418    │ missing       │ 1981-03-31 │ AA     │ 00         │ 110010001    │ 35-39 │ 07              │ GS       │ 09    │
│ 2      │ 485025    │ missing       │ 1981-03-31 │ AA     │ 00         │ 110010001    │ 40-44 │ missing         │ GS       │ 13    │
│ 3      │ 990825    │ missing       │ 1981-03-31 │ AA     │ 00         │ 110010001    │ 25-29 │ 15              │ GS       │ 15    │
│ 4      │ 1220286   │ missing       │ 1981-03-31 │ AA     │ 00         │ 110010001    │ 35-39 │ missing         │ SR       │ 00    │
⋮
│ 199996 │ 6885054   │ missing       │ 1981-03-31 │ DJ     │ 02         │ missing      │ 20-24 │ 07              │ GS       │ 04    │
│ 199997 │ 6885056   │ missing       │ 1981-03-31 │ DJ     │ 02         │ missing      │ 30-34 │ 13              │ GS       │ 10    │
│ 199998 │ 6885057   │ missing       │ 1981-03-31 │ DJ     │ 02         │ missing      │ 30-34 │ 22              │ GS       │ 10    │
│ 199999 │ 6885058   │ missing       │ 1981-03-31 │ DJ     │ 02         │ missing      │ 30-34 │ 18              │ GS       │ 10    │
│ 200000 │ 6885059   │ missing       │ 1981-03-31 │ DJ     │ 02         │ missing      │ 30-34 │ 04              │ GS       │ 04    │
...
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
