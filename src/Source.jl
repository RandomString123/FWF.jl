"""
Implement the `Data.Source` interface in the `DataStreams.jl` package.

"""
mutable struct Source{I} <: Data.Source
    schema::Data.Schema
    options::Options
    io::I
    fullpath::String
    datapos::Int # the position in the IOBuffer where the rows of data begins
    currentline::Vector{Union{Missing,String}}
    lastcol::Int
    malformed::Bool # file is malformed so slow parsing
    eolpad::Int #Number of characters to pad at end of line (typically=0, 1 for CRLF files)
    line_len::Int # first line length successfully parsed by readsplitline!
end

function Base.show(io::IO, f::Source)
    println(io, "FWF.Source: ", f.fullpath)
    println(io, "Currentline   : ")
    show(io, f.currentline)
    println(io)
    show(io, f.options)
    show(io, f.schema)
end

function union_missing(m::Bool, t::Type) 
    m ? (Union{t, Missing}) : (t)  
end

# Negative values will break these functions

# function row_calc(lines::Int, rows::Int, skip::Int, header::Bool)
#     return row_calc(lines, rows, skip) - (header ? 1 : 0)
# end

# function row_calc(lines::Int, rows::Int, skip::Int, header::T) where {T}
#     return row_calc(lines, rows, skip)
# end

# function row_calc(lines::Int, rows::Int, skip::Int)
#     # rows to process, subtract skip and header if they exist
#     rows = rows <= 0 ?  lines : ( (lines < rows) ? (lines) : (rows))
#     return skip > 1 ? rows - skip : rows
# end


function calculate_ranges(columnwidths::Union{Vector{UnitRange{Int}}, Vector{Int}})
    @static if VERSION < v"0.7.0-DEV"
        rangewidths = Vector{UnitRange{Int}}(length(columnwidths))
    else
        rangewidths = Vector{UnitRange{Int}}(uninitialized, length(columnwidths))
    end
    if isa(columnwidths, Vector{Int})
        l = 0
        for i in eachindex(columnwidths)
            columnwidths[i] < 1 && (throw(ArgumentError("A column width less than 1")))
            rangewidths[i] = l+1:l+columnwidths[i]
            l=last(rangewidths[i])
        end
    else
        #Validate the passed ranges
        first(first(columnwidths)) <= 0 && (throw(ArgumentError("Columns must start > 0")))
        for i in 1:length(columnwidths)
            first(columnwidths[i]) ≤ last(columnwidths[i]) || throw(ArgumentError(string("Negative range ", columnwidths[i])))
            rangewidths[i] = columnwidths[i]
            i==1 && (continue)
            (last(columnwidths[i-1]) < first(columnwidths[i])) || (throw(ArgumentError("Non-increasing ranges "*string(columnwidths[i-1])*","*string(columnwidths[i]))))
        end
    end
    return rangewidths
end

# Create a source data strcuture.  To do this we need to do the following
# * Ensure file exists and open for reading
# * Determine column names
# * Determine column types
# * Determine number of rows we will read
# * Convert missings to a dictionary, if applicable
# * Convert date formats to a dictionary, if applicable

function Source(
    fullpath::Union{AbstractString, IO},
    columnwidths::Union{Vector{UnitRange{Int}}, Vector{Int}}
    ;
    usemissings::Bool=true,
    trimstrings::Bool=true,
    errorlevel::Symbol=:parse,
    unitbytes::Bool=true,
    use_mmap::Bool=true,
    skip::Int=0,
    rows::Int=0,
    types::Vector=Vector(),
    header::Union{Bool, Vector{String}}=Vector{String}(),
    missings::Vector{String}=Vector{String}()
    )
    # Appemtping to re-create all objects here to minimize outside tampering
    datedict = Dict{Int, DateFormat}()
    typelist = Vector{DataType}()
    rangewidths = Vector{UnitRange{Int}}()
    malformed = false

    isa(fullpath, AbstractString) && (isfile(fullpath) || throw(ArgumentError("\"$fullpath\" is not a valid file")))
    
    # open the file and prepare for procesing
    if isa(fullpath, IOBuffer)
        source = fullpath
        fs = nb_available(fullpath)
        fullpath = "<IOBuffer>"
    elseif isa(fullpath, IO)
        source = IOBuffer(Base.read(fullpath))
        fs = nb_available(source)
        fullpath = isdefined(fullpath, :name) ? fullpath.name : "__IO__"
    else
        source = open(fullpath, "r") do f
            IOBuffer(use_mmap ? Mmap.mmap(f) : Base.read(f))
        end
        fs = filesize(fullpath)
    end

    # Number of columns = # of widths
    isempty(columnwidths) && throw(ArgumentError("No column widths provided"))
    columns = length(columnwidths)

    rangewidths = calculate_ranges(columnwidths)

    # Starting position
    startpos = position(source)
    # rows to process, subtract skip and header if they exist
    lines, eolpad =  row_countlines(source)
    skip < 0 && (skip = 0)
    rows -= skip
    # rows = row_calc(lines, rows,skip, header)
    lines ≤ (isa(header, Bool) && header) + skip && (throw(ArgumentError("More skips than rows available")))
    # Go back to start
    seek(source, startpos)

    # Don't think this is necessary, but just in case...BOM character detection
    if fs > 0 && Base.peek(source) == 0xef
         read(source, UInt8)
         read(source, UInt8) == 0xbb || seek(source, startpos)
         read(source, UInt8) == 0xbf || seek(source, startpos)
    end

    # reposition iobuffer
    tmp = skip
    while (!eof(source)) && (tmp > 0)
        readline(source)
        tmp -= 1
    end
    datapos = position(source)
    line_len = -1

    # Figure out headers
    if isa(header, Bool) && header
        # first row is heders
        header_tmp = Vector{Union{Missing,String}}()
        line_len = FWF.readsplitline!(header_tmp, source, rangewidths, true, unitbytes)
        headerlist = Vector{String}(length(header_tmp))
        datapos = position(source)
        for i in eachindex(headerlist)
            if ismissing(header_tmp[i]) || isempty(header_tmp[i])
                headerlist[i] = "Column$i"
            else
                headerlist[i] = header_tmp[i]
            end
        end
    elseif (isa(header, Bool) && !header) || isempty(header)
        # number columns
        headerlist = ["Column$i" for i = 1:columns]
    elseif !isempty(header)
        length(header) != columns && (throw(ArgumentError("Header count doesn't match column count"))) 
        headerlist = copy(header)
    else
        throw(ArgumentError("Can not determine headers")) 
    end
    
    # Type is set to String if types are not passed in
    # Otherwise iterate through copying types & creating date dictionary
    if isempty(types)
        typelist = [union_missing(usemissings, String) for i = 1:columns]
    else
        length(types) != columns && throw(ArgumentError("Wrong number of types: "*string(length(types))))
        @static if VERSION < v"0.7.0-DEV"
            typelist = Vector{Type}(columns)
        else
            typelist = Vector{Type}(uninitialized, columns)
        end
        for i in 1:length(types)
            if (isa(types[i], DateFormat))
                typelist[i] = union_missing(usemissings, Date)
                datedict[i] = types[i]
            elseif (isa(types[i], Type))
                !(types[i] in (Int, Float64, String, Missing)) && (throw(ArgumentError("Invalid Type: "*string(types[i]))))
                isa(types[i], Missing) ? Missing : typelist[i] = union_missing(usemissings, types[i])
            else
               throw(ArgumentError("Found type that is not a DateFormat or DataType")) 
            end
        end
    end

    # Convert missings to Set for faster lookup later.
    missingset=Set{String}(missings)

    sch = Data.Schema(typelist, headerlist, ifelse(rows ≤ 0, missing, rows))
    opt = Options(usemissings=usemissings, trimstrings=trimstrings, 
                    errorlevel=errorlevel, unitbytes=unitbytes, skip=skip, missingvals=missingset,
                    dateformats = datedict,
                    columnrange=rangewidths)
    return Source(sch, opt, source, string(fullpath), datapos, Vector{Union{Missing,String}}(), 0, malformed, eolpad, line_len)
end

# needed? construct a new Source from a Sink
#Source(s::CSV.Sink) = CSV.Source(fullpath=s.fullpath, options=s.options)
Data.reset!(s::FWF.Source) = (seek(s.io, s.datapos); return nothing)
Data.schema(source::FWF.Source) = source.schema
Data.accesspattern(::Type{<:FWF.Source}) = Data.Sequential
@inline Data.isdone(io::FWF.Source, row, col, rows, cols) = eof(io.io) || (!ismissing(rows) && row > rows)
#@inline Data.isdone(io::Source, row, col) = Data.isdone(io, row, col, size(io.schema)...)
Data.streamtype(::Type{<:FWF.Source}, ::Type{Data.Column}) = false
Data.streamtype(::Type{<:FWF.Source}, ::Type{Data.Field}) = true
@inline Data.streamfrom(source::FWF.Source, ::Type{Data.Field}, ::Type{T}, row, col::Int) where {T} = FWF.parsefield(source, T, row, col)
Data.streamfrom(source::FWF.Source, ::Type{Data.Column}, ::Type{T}, col::Int) where {T} = FWF.parsecol(source, T, col)
Data.reference(source::FWF.Source) = source.io.data
