# Test items in source.jl

file = joinpath(dir,"testfile.txt")

@testset "Source Generation" begin
    b = """
       abcd    10102017
       efgh123410102018"""

    @test_throws ArgumentError FWF.Source("", [1])
    @test_throws ArgumentError FWF.Source(file, Vector{Int}())
    @test_throws ArgumentError FWF.Source(file, [4,4,8], header=["A", "B"])
    @test_throws ArgumentError FWF.Source(file, [4,4,8], types=["A", "B"])
    @test_throws ArgumentError FWF.Source(file, [4,4,8], types=[Int64, 1234, String])
    @test_throws ArgumentError FWF.Source(file, [4,4,8], types=[String, Float32, DateFormat("mmddyyyy")])

    tmp = FWF.Source(file, [4,4,8])
    show(IOBuffer(), tmp) # Will retult in exception if problem unfortunately there is no @test_notthrows
    @test Data.header(tmp.schema)[1] == "Column1"
    @test Data.header(tmp.schema)[2] == "Column2"
    @test Data.header(tmp.schema)[3] == "Column3"

    tmp = FWF.Source(open(file, "r"), [4,4,8], header=true)
    @test Data.header(tmp.schema)[1] == "abcd"
    @test Data.header(tmp.schema)[2] == "1234"
    @test Data.header(tmp.schema)[3] == "10102017"

    tmp = FWF.Source(IOBuffer(b), [4,4,8], header=true)
    @test Data.header(tmp.schema)[1] == "abcd"
    @test Data.header(tmp.schema)[2] == "Column2"
    @test Data.header(tmp.schema)[3] == "10102017"
    @test Data.types(tmp.schema)[1] == Union{Missing, String}
    @test Data.types(tmp.schema)[2] == Union{Missing, String}
    @test Data.types(tmp.schema)[3] == Union{Missing, String}
    tmp = FWF.Source(file, [4,4,8], types=[String, Int, Float64])
    @test Data.types(tmp.schema)[1] == Union{Missing, String}
    @test Data.types(tmp.schema)[2] == Union{Missing, Int64}
    @test Data.types(tmp.schema)[3] == Union{Missing, Float64}
    tmp = FWF.Source(file, [4,4,8], types=[String, Int, DateFormat("mmddyyyy")], missings=["NA","***"])
    @test Data.types(tmp.schema)[1] == Union{Missing, String}
    @test Data.types(tmp.schema)[2] == Union{Missing, Int64}
    @test Data.types(tmp.schema)[3] == Union{Missing, Date}
    @test tmp.options.dateformats[3] == DateFormat("mmddyyyy")
    @test "***" in tmp.options.missingvals
    @test "NA" in tmp.options.missingvals
end

@testset "Functions" begin
    b = """
    abc
    def"""

    # Range building
    @test_throws ArgumentError FWF.calculate_ranges([-1,2,3])
    @test_throws ArgumentError FWF.calculate_ranges([-1:2])
    @test_throws ArgumentError FWF.calculate_ranges([1:2, 1:5])
    @test_throws ArgumentError FWF.calculate_ranges([1:5, 6:5])
    tmp = FWF.calculate_ranges([1,4,6])
    @test tmp[1] == 1:1
    @test tmp[2] == 2:5
    @test tmp[3] == 6:11
    tmp = FWF.calculate_ranges([1:1, 2:5, 6:11])
    @test tmp[1] == 1:1
    @test tmp[2] == 2:5
    @test tmp[3] == 6:11

end
