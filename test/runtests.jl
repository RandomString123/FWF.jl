using Missings
using FWF
using DataStreams
using DataFrames

@static if VERSION < v"0.7.0-DEV.2005"
    using Base.Test
else
    using Test
end
if VERSION < v"0.7.0-DEV.2575"
    using Base.Dates
else
    using Dates
end


dir = joinpath(dirname(@__FILE__),"testfiles/")

include("FWF.jl")
include("Source.jl")
include("parsefields.jl")
include("io.jl")
include("scan.jl")

