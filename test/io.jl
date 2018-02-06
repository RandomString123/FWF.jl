file = joinpath(dir,"testfile.txt")
file2 = joinpath(dir,"sal.txt")

@testset "readsplitline! Testing" begin
    s = Vector{String}()
    tmp = FWF.Source(file, [4,4,8])
    FWF.readsplitline!(s, tmp)
    @test s[1] == "abcd"
    @test s[2] == "1234"
    @test s[3] == "10102017"
    @test_throws ArgumentError FWF.readsplitline!(s, tmp.io, Vector{UnitRange{Int}}())
    FWF.readsplitline!(s, tmp)
    @test s[1] == "efgh"
    @test s[2] == "5678"
    @test s[3] == "10112017"
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
    
    #ensure utf 8 doesn't mess us up
    b = """
    abcd
    \u263ae
    fghi
    """
    tmp = FWF.Source(IOBuffer(b),[4])
    @test FWF.readsplitline!(s, tmp)[1] == "abcd"
    @test FWF.readsplitline!(s, tmp)[1] == "\u263ae"
    @test FWF.readsplitline!(s, tmp)[1] == "fghi"
    @test_throws ArgumentError FWF.readsplitline!(s, tmp)[1]


end

@testset "FWF.read Testing" begin
    tmp = FWF.read(IOBuffer("abc12310102017\ndef45610112017\n"), [3,3,8], types=[String,Int,DateFormat("mmddyyyy")])
    @test tmp[1,1] == "abc"
    @test tmp[1,2] == 123
    @test tmp[1,3] == Date(2017,10,10)
    @test tmp[2,1] == "def"
    @test tmp[2,2] == 456
    @test tmp[2,3] == Date(2017,10,11)
    strrep(s::String, r::UnitRange) = [repeat(s, n) for n in r]
    naValues = vcat(strrep("*", 1:23), strrep("#", 1:23), "NAME WITHHELD BY AGENCY", "NAME WITHHELD BY OPM", "NAME UNKNOWN", "UNSP", "<NA>", "000000", "999999", "")

    #    ~FieldName,~Length,~Type,
    format = DataFrame(["PSEUDO-ID" 9 Int;
    "EMPLOYEE_NAME" 23 Missing;
    "FILE_DATE" 8  DateFormat("yyyymmdd");
    "AGENCY" 2 String;
    "SUB_AGENCY" 2 String;
    "DUTY_STATION" 9 String;
    "AGE" 6 String;
    "EDUCATION_LEVEL" 2 String;
    "PAY_PLAN" 2 String;
    "GRADE" 2 String;
    "LOS_LEVEL" 6 String;
    "OCCUPATION" 4 String;
    "OCCUPATIONAL_CATEGORY" 1 String;
    "ADJUSTED_BASIC_PAY" 6 Int;
    "SUPERVISORY_STATUS" 1 String;
    "TYPE_OF_APPOINTMENT" 2 String;
    "WORK_SCHEDULE" 1 String;
    "NSFTP_IND"  1 String])

    tmp = FWF.read(file2, convert(Array{Int},format[:x2]), 
        header=convert(Array{String}, format[:x1]), types=convert(Array{Union{Type, DateFormat}},format[:x3]), 
        missings=naValues)
    
    @test ismissing(tmp[2,8])
    @test tmp[150651,4] == "CM"
    @test ismissing(tmp[15321,13])
    @test tmp[15333,13] == "P"
    @test tmp[153242,16] == "15"
    @test tmp[9999,4] == "AG"
end