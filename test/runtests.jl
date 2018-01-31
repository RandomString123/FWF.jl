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
#include("FWF.jl")
#include("io.jl")

dir = joinpath(dirname(@__FILE__),"test_files/")
# dir = joinpath(Pkg.dir("CSV"), "test/test_files")

#include("source.jl")
#include("multistream.jl")
#include("validate.jl")

# Test code to ensure that objects create correctly.
