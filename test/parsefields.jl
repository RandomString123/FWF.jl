
@testset "Parse Testing" begin
    tmp = FWF.Source(file, [4,4,8], types=[String, Int, DateFormat("mmddyyyy")], missingcheck=false, missings=["abcd","10112017"])
    @test !FWF.missingon(tmp)
    @test FWF.checkmissing("abcd", tmp.options.missingvals)
    @test FWF.get_format(tmp, 1) == nothing
    @test FWF.get_format(tmp, 3) == DateFormat("mmddyyyy")
    @test_throws FWF.ParsingException FWF.parsefield(tmp, Int, 3)
    @test FWF.parsefield(tmp, String, 1) = "abcd"
    @test FWF.parsefield(tmp, Int, 2) = 1234
    @test FWF.parsefield(tmp, Date, 3) = Date("2017-10-10")
    @test_throws BoundsError FWF.parsefield(tmp, Date, 4)
    b = """
    2.1
    3.2"""
    # Validate floats work and multiline reading works
    tmp = FWF.Source(IOBuffer(b),[3], types=[Float64])
    FWF.parsefield(tmp, Float64, 1) == 2.1
    FWF.parsefield(tmp, Float64, 1) == 3.2
    @test_throws ArgumentError FWF.parsefield(tmp, Float64, 1)
end