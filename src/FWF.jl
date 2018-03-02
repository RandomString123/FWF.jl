__precompile__(true)
module FWF

@static if VERSION < v"0.7.0-DEV.2005"
    using DataStreams, Missings, DataFrames
else 
    using DataStreams, Missings, DataFrames, Dates, Mmap
end



struct ParsingException <: Exception
    msg::String
end

"""
Configuration Settings for fixed width file parsing.

  * `skip`        : integer of the number of lines to skip; default `0`
  * `trimstrings` : true if strings should be trimmed; default `true`
  * `usemissings` : true if fields should be checked for null values; default `true`
  * `errorlevel`  : if `:parse` then as much as possible is parsed and missing data is replaced by `missing`;
                    if `:skip` then malformed line is skipped on error;
                    if `:error` then an exception is thrown on error; default `:parse`
  * `countnybytes`: true if field parsing should happen by bytes, false for character based parsing; default `true` 
  * `missingvals` : Set{String} for values that equal missing
  * `dateformats` : Dictionary in the form of Int=>DateFormat to specify date formats for a column
  * `columnrange` : Vector of UnitRanges that specifcy the widths of each column.
  * ``
"""

struct Options
    usemissings::Bool
    trimstrings::Bool
    errorlevel::Symbol
    unitbytes::Bool
    skip::Int
    missingvals::Set{String}
    dateformats::Dict{Int, DateFormat}
    columnrange::Vector{UnitRange{Int}}
end

function Options(;usemissings=true, trimstrings=true, errorlevel=:parse, unitbytes=true,
                 skip=0, missingvals=Set{String}(),
                 dateformats=Dict{Int, DateFormat}(), columnrange=Vector{UnitRange{Int}}())
    if !usemissings && (errorlevel == :parse)
        println(STDERR, "Warning: Combination of usemissings==false and errorlevel==:parse\n"*
               "will lead to an error when malformed lines are present in the data.\n"*
               "In order to avoid this set usemissings to true or errorlevel to :skip.")
    end
    if !(errorlevel in [:parse, :skip, :error])
        throw(ArgumentError("Allowed values for errorlevel are :parse, :skip or :error"))
    end
    Options(usemissings, trimstrings, errorlevel, unitbytes,
            skip, missingvals, dateformats, columnrange)
end

function Base.show(io::IO, op::Options)
    println(io, "   FWF.Options:")
    println(io, "     nullcheck: ", op.usemissings)
    println(io, "   trimstrings: ", op.trimstrings)
    println(io, "   errorlevel: ", op.errorlevel)
    println(io, "  countbybytes: ", op.unitbytes)
    println(io, "          skip: ", op.skip)
    println(io, "   missingvals:", )
    show(io, op.missingvals)
    println(io)
    println(io, "   dateformats:")
    show(io, op.dateformats)
    println(io)
    println(io, "   columnranges:")
    show(io, op.columnrange)
    println(io)
end

include("Source.jl")
include("parsefields.jl")
include("io.jl")
include("scan.jl")
end
