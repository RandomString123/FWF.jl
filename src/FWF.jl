__precompile__(true)
module FWF

using DataStreams, Missings, DataFrames, Dates

struct ParsingException <: Exception
    msg::String
end

"""
Configuration Settings for fixed width file parsing.

  * `skip`: integer of the number of lines to skip; default `0`
  * `trimstrings`: true if strings should be trimmed; default `true`
  * `usemissings`: true if fields should be checked for null values; default `true`
  * `missingvals`: Dictionary in form of String=>missing for values that equal missing
  * `dateformats`: Dictionary in the form of Int=>DateFormat to specify date formats for a column
  * `columnrange`: Vector of UnitRanges that specifcy the widths of each column.
  * ``
"""

struct Options
    usemissings::Bool
    trimstrings::Bool
    skiponerror::Bool
    skip::Int
    missingvals::Dict{String, Missing}
    dateformats::Dict{Int, DateFormat}
    columnrange::Vector{UnitRange{Int}}
end

 Options(;usemissings=true, 
        trimstrings=true, skiponerror=true, skip=0, 
        missingvals=Dict{String, Missing}(), 
        dateformats=Dict{Int, DateFormat}(),
        columnrange=Vector{UnitRange{Int}}()) =
    Options(usemissings, trimstrings, skiponerror, skip, missingvals, 
            dateformats, columnrange)

function Base.show(io::IO, op::Options)
    println(io, "   FWF.Options:")
    println(io, "     nullcheck: ", op.usemissings)
    println(io, "   trimstrings: ", op.trimstrings)
    println(io, "   skiponerror: ", op.skiponerror)
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
