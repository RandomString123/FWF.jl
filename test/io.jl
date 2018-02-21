file = joinpath(dir,"testfile.txt")
file2 = joinpath(dir,"sal.txt")

@testset "Line Count Testing" begin
    # Malformed line
    ml = "aaaa\nbbb\ncccc\n"
    #No Ending NL
    nonl = "aaaa\nbbbb\ncccc"
    #Extra junk at end
    extra = "aaaa\nbbbb\ncccc\ndd"
    #Carrige Retruns
    cr = "aaaa\r\nbbbb\r\ncccc\r\n"
    #Normal
    b = "aaaa\nbbbb\ncccc\n"
    # no data
    nodata = ""
    #test base.countlines for fix to counting so we can adjust code
    @test countlines(IOBuffer(nonl)) == 2
    @test countlines(IOBuffer(b)) == 3
    @test FWF.mod_countlines(IOBuffer(nonl)) == 3
    @test FWF.mod_countlines(IOBuffer(b)) == 3
    @test FWF.mod_countlines(IOBuffer(" ")) == 1
    @test FWF.mod_countlines(IOBuffer("")) == 0
    # Not error until malformed is back
    #@test_throws FWF.ParsingException FWF.row_countlines(IOBuffer(ml))
    @test FWF.row_countlines(IOBuffer(ml)) == (3, 0)
    @test FWF.row_countlines(IOBuffer(nonl)) == (3, 0)
    # Used to be an error condition not now.
    #@test_throws FWF.ParsingException FWF.row_countlines(IOBuffer(extra))
    @test FWF.row_countlines(IOBuffer(extra)) == (4, 0)
    @test FWF.row_countlines(IOBuffer(b)) == (3, 0)
    @test FWF.row_countlines(IOBuffer(cr)) == (3, 1)
    @test FWF.row_countlines(IOBuffer(nodata)) == (0, 0)
end

@testset "readsplitline! Testing" begin
    s = Vector{Union{Missing,String}}()
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

    tmp = FWF.Source(file, [4,4,4])
    FWF.readsplitline!(s, tmp)
    @test s[1] == "abcd"
    @test s[2] == "1234"
    @test s[3] == "1010"
    @test_throws ArgumentError FWF.readsplitline!(s, tmp.io, Vector{UnitRange{Int}}())
    FWF.readsplitline!(s, tmp)
    @test s[1] == "efgh"
    @test s[2] == "5678"
    @test s[3] == "1011"
    @test_throws ArgumentError FWF.readsplitline!(s, tmp)

    tmp = FWF.Source(file, [1:4,5:8,9:16])
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

    tmp = FWF.Source(file, [1:2,5:6,9:10])
    FWF.readsplitline!(s, tmp)
    @test s[1] == "ab"
    @test s[2] == "12"
    @test s[3] == "10"
    @test_throws ArgumentError FWF.readsplitline!(s, tmp.io, Vector{UnitRange{Int}}())
    FWF.readsplitline!(s, tmp)
    @test s[1] == "ef"
    @test s[2] == "56"
    @test s[3] == "10"
    @test_throws ArgumentError FWF.readsplitline!(s, tmp)
    Data.reset!(tmp)
    @test Data.accesspattern(tmp) == Data.Sequential() # not sure why this isn't a type
    FWF.readsplitline!(s, tmp)
    @test s[1] == "ab"
    @test s[2] == "12"
    @test s[3] == "10"
    @test_throws ArgumentError FWF.readsplitline!(s, tmp.io, Vector{UnitRange{Int}}())

    b="""
    aaaa
    bbb
    cccc"""
    tmp = FWF.Source(IOBuffer(b),[4], errorlevel=:skip)
    @test FWF.readsplitline!(s, tmp) == 4
    @test s[1] == "aaaa"
    @test FWF.readsplitline!(s, tmp) == 4
    @test s[1] == "cccc"
    # Not error until malformed is back
    #@test_throws FWF.ParsingException FWF.Source(IOBuffer(b),[4],skiponerror=false)
    tmp = FWF.Source(IOBuffer(b),[4], errorlevel=:skip)
    @test FWF.readsplitline!(s, tmp) == 4
    @test s[1] == "aaaa"
    # @test tmp.schema.rows == 3
    #@test_throws FWF.ParsingException FWF.readsplitline!(s, tmp)
    @test FWF.readsplitline!(s, tmp) == 4
    @test s[1] == "cccc"

    # test overlong line
    b="""
    aaaa
    bbb
    ccccc"""
    tmp = FWF.Source(IOBuffer(b),[4], errorlevel=:skip)
    @test FWF.readsplitline!(s, tmp) == 4
    @test s[1] == "aaaa"
    @test FWF.readsplitline!(s, tmp) == 5
    @test s[1] == "cccc"
    

    # test overlong line
    b="""
    aaaaa
    bbb
    cccc"""
    tmp = FWF.Source(IOBuffer(b),[4], errorlevel=:skip)
    @test FWF.readsplitline!(s, tmp) == 5
    @test s[1] == "aaaa"
    @test FWF.readsplitline!(s, tmp) == 4
    @test s[1] == "cccc"

    #ensure utf 8 doesn't mess us up
    b = """
    abcd
    \u263ae
    fghi
    """
    tmp = FWF.Source(IOBuffer(b),[4])
    @test FWF.readsplitline!(s, tmp) == 4
    @test s[1] == "abcd"
    @test FWF.readsplitline!(s, tmp) == 4
    @test s[1] == "\u263ae"
    @test FWF.readsplitline!(s, tmp) == 4
    @test s[1] == "fghi"
    @test_throws ArgumentError FWF.readsplitline!(s, tmp)
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
    format = DataFrame(["PSEUDO_ID" 9 Int;
    "EMPLOYEE_NAME" 23 String;
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
    @test tmp[36, 2] == "NAME WITHHELD BY ÄĜË"

    # Simple UTF-8 test
    tmp = FWF.read(IOBuffer("α1x\na2y\n∀∅z"), [1,1,1], unitbytes=false)
    @test tmp[1,1] == "α"
    @test tmp[1,2] == "1"
    @test tmp[2,2] == "2"
    @test tmp[3,2] == "∅"
    @test tmp[3,3] == "z"
    tmp = FWF.read(IOBuffer("α1x\na2y\n∀∅z"), [2,1], unitbytes=false)
    @test tmp[1,1] == "α1"
    @test tmp[2,1] == "a2"
    @test tmp[3,1] == "∀∅"
    @test tmp[3,2] == "z"
    tmp = FWF.read(IOBuffer("α1x\na2y\n∀∅z"), [3], unitbytes=false)
    @test tmp[1,1] == "α1x"
    @test tmp[2,1] == "a2y"
    @test tmp[3,1] == "∀∅z"

    tmp = FWF.read(IOBuffer("α1\na\n∀∅z"), [1,1,1], unitbytes=false)
    @test tmp[1,1] == "α"
    @test tmp[1,2] == "1"
    @test ismissing(tmp[2,2])
    @test tmp[3,2] == "∅"
    @test tmp[3,3] == "z"
    @test ismissing(tmp[1,3])
    @test ismissing(tmp[2,3])

    @test_throws FWF.ParsingException FWF.read(IOBuffer("α1\na\n∀∅z"), [1,1,1], unitbytes=false, errorlevel=:error)

    tmp = FWF.read(IOBuffer("α1\na\n∀∅z"), [1,1,1], unitbytes=false, errorlevel=:skip)
    @test nrow(tmp) == 1
    @test tmp[1,1] == "∀"
    @test tmp[1,2] == "∅"
    @test tmp[1,3] == "z"

    tmp = FWF.read(IOBuffer("αąx\na2y\n∀∅z"), [1,1,1], unitbytes=false, header=true)
    @test names(tmp) == [:α, :ą, :x]
    @test nrow(tmp) == 2

    tmp = FWF.read(IOBuffer("αąx\naby\n∀∅z"), [1,1,1], unitbytes=false, header=true, skip = 1)
    @test names(tmp) == [:a, :b, :y]
    @test nrow(tmp) == 1

    @test_throws ArgumentError FWF.read(IOBuffer("αąx\na2y\n∀∅z"), [1,1,1], unitbytes=false, header=true, skip = 2)

    @test_throws ArgumentError FWF.read(IOBuffer("αąx\na2y\n∀∅z"), [1,1,1], unitbytes=false, header=false, skip = 3)
    @test nrow(FWF.read(IOBuffer("αąx\na2y\n∀∅z"), [1,1,1], unitbytes=false, header=false, skip = 2)) == 1
    @test nrow(FWF.read(IOBuffer("αąx\na2y\n∀∅z"), [1,1,1], unitbytes=false, header=false, skip = 1)) == 2
end
