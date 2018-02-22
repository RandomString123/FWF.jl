# Test items in FWF.jl file

# Ensure options objects get created
@testset "Options Tests" begin
    x = FWF.Options()
    @test x.usemissings == true
    @test x.trimstrings == true
    @test x.errorlevel == :parse
    @test x.unitbytes == true
    @test x.skip == 0
    @test x.missingvals == Set{String}()
    @test x.dateformats == Dict{Int, DateFormat}()
    @test x.columnrange == Vector{UnitRange{Int}}()

    m = Set{String}(["***"])
    d = Dict{Int, DateFormat}(1 => DateFormat("mmddyy"))
    x = [1:10, 2:20]
    tmp = FWF.Options(usemissings=false, trimstrings=false, errorlevel=:skip,
                      unitbytes=false, skip=10, missingvals=m, dateformats=d, columnrange=x)
    @test tmp.usemissings == false
    @test tmp.trimstrings == false
    @test tmp.errorlevel == :skip
    @test tmp.unitbytes == false
    @test tmp.skip == 10
    @test tmp.missingvals == m
    @test tmp.dateformats == d
    @test tmp.columnrange == x

    @test_throws ArgumentError FWF.Options(usemissings=false, trimstrings=false,
                                           errorlevel=:x, unitbytes=false, skip=10,
                                           missingvals=m, dateformats=d, columnrange=x)
end
