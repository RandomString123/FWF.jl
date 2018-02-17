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
  * `skiponerror` : true if errors should not throw an exception; default `true`
  * `countnybytes`: true if field parsing should happen by bytes, false for character based parsing; default `true` 
  * `missingvals` : Dictionary in form of String=>missing for values that equal missing
  * `dateformats` : Dictionary in the form of Int=>DateFormat to specify date formats for a column
  * `columnrange` : Vector of UnitRanges that specifcy the widths of each column.
  * ``
"""

struct Options
    usemissings::Bool
    trimstrings::Bool
    skiponerror::Bool
    unitbytes::Bool
    skip::Int
    missingvals::Dict{String, Missing}
    dateformats::Dict{Int, DateFormat}
    columnrange::Vector{UnitRange{Int}}
end

 Options(;usemissings=true, 
        trimstrings=true, skiponerror=true, unitbytes=true, skip=0, 
        missingvals=Dict{String, Missing}(), 
        dateformats=Dict{Int, DateFormat}(),
        columnrange=Vector{UnitRange{Int}}()) =
    Options(usemissings, trimstrings, skiponerror, unitbytes, skip, missingvals, 
            dateformats, columnrange)

function Base.show(io::IO, op::Options)
    println(io, "   FWF.Options:")
    println(io, "     nullcheck: ", op.usemissings)
    println(io, "   trimstrings: ", op.trimstrings)
    println(io, "   skiponerror: ", op.skiponerror)
    println(io, "  countbybytes: ", op.countbybytes)
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
end
