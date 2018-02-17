# Test items in FWF.jl file

# Ensure options objects get created
@testset "Options Tests" begin
    x = FWF.Options()
    @test x.usemissings == true
    @test x.trimstrings == true
    @test x.skiponerror == true
    @test x.countbybytes == true
    @test x.skip == 0
    @test x.missingvals == Dict{String, Missing}()
    @test x.dateformats == Dict{Int, DateFormat}()
    @test x.columnrange == Vector{UnitRange{Int}}()
end