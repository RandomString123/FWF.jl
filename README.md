#  FWF

*A simple fixed width file parser for julia*

*maintained by @bkamins and @randomstring123*


| **PackageEvaluator**                                            | **Build Status**                                                                                |
:---------------------------------------------------------------:|:-----------------------------------------------------------------------------------------------:|
| [![][pkg-0.6-img]][pkg-0.6-url] | [![][travis-img]][travis-url] [![][codecov-img]][codecov-url] |


## Background
This package uses CSV.jl as an inspration and a code template for parsing
fixed width data files and loading them into julia.  It has the features
* Parse based on single bytes or utf-8 characters as unit type
* Data field conversion into Int, Missing, Float64, and Date types
* Line parsing and field parsing based on Int or UnitRange field widths.
* Ability to parse non-contigious fields.
* Supports DataStream Source functionality to enable streaming into a DataFrame...or anything that implements Sink.
* Robust missing value detection
* Skip or parse malformed rows without terminating parsing
* Custom header specifiction
* Start of file row skipping
* Autodetect column widths if there is a separator between them using `scan` function

Items of note the package does not support, but could if desired
* Column type detection
* Sink from DataStreams. 

## Installation

The package is registered in `METADATA.jl` and so can be installed with `Pkg.add`.

```julia
julia> Pkg.add("FWF")
```

## Project Status

The package is tested against Julia `0.6` and (Currently Broken) nightly on Linux, OS X.

## Contributing and Questions

Contributions are very welcome, as are feature requests and suggestions. Please open an
[issue][issues-url] if you encounter any problems or would just like to ask a question.


[travis-img]: https://travis-ci.org/RandomString123/FWF.jl.svg?branch=master
[travis-url]: https://travis-ci.org/RandomString123/FWF.jl?branch=master

[codecov-img]: https://codecov.io/gh/RandomString123/FWF.jl/branch/master/graph/badge.svg
[codecov-url]: https://codecov.io/gh/RandomString123/FWF.jl

[issues-url]: https://github.com/RandomString123/FWF.jl/issues

[pkg-0.6-img]: http://pkg.julialang.org/badges/FWF_0.6.svg
[pkg-0.6-url]: http://pkg.julialang.org/?pkg=FWF
