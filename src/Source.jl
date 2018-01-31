
"""
Implement the `Data.Source` interface in the `DataStreams.jl` package.

"""
mutable struct Source{I} <: Data.Source
    schema::Data.Schema
    options::Options
    io::I
    fullpath::String
    datapos::Int # the position in the IOBuffer where the rows of data begins
    currentline::Vector{String}
end

function Base.show(io::IO, f::Source)
    println(io, "FWF.Source: ", f.fullpath)
    println(io, "Currentline   : ")
    show(io, f.columnwidths)
    show(io, f.options)
    show(io, f.schema)
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
    missingcheck::Bool=true,
    trimstrings::Bool=true,
    skip::Int=0,
    header::Union{Bool, Vector{String}}=Vector{String}(),
    missings::Vector{String}=Vector{String}(),
    use_mmap::Bool=true,
    rows::Int=0,
    types::Vector{Union{Type, DateFormat}}=Vector{Union{Type, DateFormat}}()
    )
    datedict = Dict{Int, DateFormat}
    typelist = Vector{Type}
    missingdict = Dict{String, Bool}

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

    # Starting position
    startpos = position(source)
    # rows to process, subtract skip and header if they exist
    rows = rows == 0 ? countlines(source) : rows
    rows = skip > 1 ? rows - skip : rows
    rows = (isa(header, Bool) && header) ? rows  - 1 : rows

    seek(source, startpos)

    # Don't think this is necessary, but just in case utf sneaks in...BOM character detection
    if fs > 0 && Base.peek(source) == 0xef
         read(source, UInt8)
         read(source, UInt8) == 0xbb || seek(source, startpos)
         read(source, UInt8) == 0xbf || seek(source, startpos)
    end

    # Number of columns = # of widths
    (columnwidths != nothing) && (isempty(columnwidths) || throw(ArgumentError("No column widths provided")))
    columns = length(columnwidths)

    rangewidths = Vector{UnitRange{Int}}(length(columnwidths))
    if isa(columnwidths, Vector{Int})
        last = 1
        for i in eachindex(columnwidths)
            rangewidths[i] = last+1:columnwidths[i]
            last=last(rangewidths[i])
        end
    else
        rangewidths = columnwidths
        #Validate we have an unbroken range
        for i in 1:length(columnwidths)
            i==1 && (continue)
            (last(columnwidths[i-1])+1 != first(columnwidths[i])) && (throw(ArgumentError("Non-Continuous ranges "*columnwidths[i=1]*" "*columnwidths[i]))) 
        end
    end

    rowlength = last(last(rangewidths))
    for width in columnwidths
        rowlength += width
    end

    tmp = skip
    while (!eof(source)) && (tmp > 1)
        readline(source)  
        tmp =- 1     
    end
    datapos = position(source)

    header_vals = Vector{String}()
    # Figure out headers
    if isa(header, Bool) && header
        # first row is heders
        headers = [strip(x.value) for x in FWF.readsplitline!(row_vals, source,rangewidths)]
        datapos = position(source)
        for i in eachindex(headers)
            length(headers[i]) < 1 && (headers[i] = "Column$i")
        end
    elseif (isa(headers, Bool) && !headers) || isempty(header)
        # number columns
        headers = ["Column$i" for i = 1:columns]
    elseif !isempty(headers)
        length(headers) != columns && (throw(ArgumentError("Headers doesn't match columns"))) 
    else
        throw(ArgumentError("Can not determine headers")) 
    end
    
    # Type is set to String if types are not passed in
    # Otherwise iterate through copying types & creating date dictionary
    if isempty(types)
        typelist = [String for i = 1:columns]
    else
        length(types) != columns && throw(ArgumentError("Wrong number of types: "*length(types)))
        for i in 1:length(types)
            if (isa(types[i], DateFormat))
                typelist[i] = Date
                datedict[i] = types[i]
            else 
                typelist[i] = types[i]
            end
        end
    end

    # Convert missings to dictionary for faster lookup later.
    if !isempty(missings) 
        for entry in missings
            missingdict[entry] = missing
        end
    end

    sch = Data.Schema(typelist, headers, ifelse(rows < 0, missing, rows))
    opt = Options(missingcheck=missingcheck, trimstrings=trimstrings, 
                    skip=skip, missingvals=missingdict, 
                    dateformats = datedict,
                    columnrange=columnwidths)
    return Source(sch, opt, source, string(fullpath), datapos, Vector{String}())
end

# needed? construct a new Source from a Sink
#Source(s::CSV.Sink) = CSV.Source(fullpath=s.fullpath, options=s.options)
Data.reset!(s::FWF.Source) = (seek(s.io, s.datapos); return nothing)
Data.schema(source::FWF.Source) = source.schema
Data.accesspattern(::Type{<:FWF.Source}) = Data.Sequential
@inline Data.isdone(io::FWF.Source, row, col, rows, cols) = eof(io.io) || (!ismissing(rows) && row > rows)
@inline Data.isdone(io::Source, row, col) = Data.isdone(io, row, col, size(io.schema)...)
Data.streamtype(::Type{<:FWF.Source}, ::Type{Data.Column}) = true
#@inline Data.streamfrom(source::FWF.Source, ::Type{Data.Field}, ::Type{T}, row, col::Int) where {T} = FWF.parsefield(source.io, T, source.options, row, col)
Data.streamfrom(source::FWF.Source, ::Type{Data.Column}, ::Type{T}, col::Int) where {T} = FWF.parsefield(source, T, col)
Data.reference(source::FWF.Source) = source.io.data
