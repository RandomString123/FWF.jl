file = joinpath(dir,"testfile.txt")

@testset "Parse Testing" begin
    tmp = FWF.Source(file, [4,4,8], types=[String, Int, DateFormat("mmddyyyy")],
                     usemissings=false, missings=["abcd","10112017"])
    @test !FWF.missingon(tmp)
    tmp = FWF.Source(file, [4,4,8], types=[String, Int, DateFormat("mmddyyyy")],
                     missings=["abcd","10112017"])
    @test FWF.checkmissing("abcd", tmp.options.missingvals)
    @test FWF.get_format(tmp, 1) == nothing
    @test FWF.get_format(tmp, 3) == DateFormat("mmddyyyy")
    @test_throws FWF.ParsingException FWF.parsefield(tmp, Int, 1, 3)
    tmp = FWF.Source(file, [4,4,8], types=[String, Int, DateFormat("mmddyyyy")],
                     missings=["abcd","10112017"])
    @test ismissing(FWF.parsefield(tmp, String, 1, 1))
    @test FWF.parsefield(tmp, Int, 1, 2) == 1234
    @test FWF.parsefield(tmp, Date, 1, 3) == Date("2017-10-10")
    @test FWF.parsefield(tmp, String, 2, 1) == "efgh"
    @test ismissing(FWF.parsefield(tmp, Missing, 2, 2))
    @test ismissing(FWF.parsefield(tmp, Date, 2, 3))
    @test_throws BoundsError FWF.parsefield(tmp, Date, 2, 4)
    b = """
    2.1
    3.2"""
    # Validate floats work and multiline reading works
    tmp = FWF.Source(IOBuffer(b),[3], types=[Float64])
    FWF.parsefield(tmp, Float64, 1, 1) == 2.1
    FWF.parsefield(tmp, Float64, 2, 1) == 3.2
    @test_throws ArgumentError FWF.parsefield(tmp, Float64, 1, 1)
end
