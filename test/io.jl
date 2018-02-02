file = joinpath(dirname(@__FILE__),"testfile.txt")

@testset "readsplitline! Testing" begin
    s = Vector{String}()
    tmp = FWF.Source(file, [4,4,8])
    FWF.readsplitline!(s, tmp)
    @test s[1] = "abcd"
    @test s[2] = "1234"
    @test s[3] = "10102017"
    @test_throws ArgumentError FWF.readsplitline!(s, tmp.io, Vector{UnitRange{Int}}())
    FWF.readsplitline!(s, tmp)
    @test s[1] = "efgh"
    @test s[2] = "5678"
    @test s[3] = "10112017"
    @test_throws ArgumentError FWF.readsplitline!(s, tmp)
    b="""
    aaaa
    bbb
    cccc"""
    tmp = FWF.Source(IOBuffer(b),[4])
    @test FWF.readsplitline!(s, tmp)[1] == "aaaa"
    @test FWF.readsplitline!(s, tmp)[1] == "cccc"
    tmp = FWF.Source(IOBuffer(b),[4],skiponerror=false)
    @test FWF.readsplitline!(s, tmp)[1] == "aaaa"
    @test_throws FWF.ParsingException FWF.readsplitline!(s, tmp)
    @test FWF.readsplitline!(s, tmp)[1] == "cccc"
end

@testset "FWF.read Testing" begin
end