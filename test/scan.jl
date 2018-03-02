@testset "scan char" begin
    @test FWF.scan("testfiles/test1.txt") == [1:1, 3:19, 21:48]
    @test FWF.scan("testfiles/test1.txt", skip=1) == [3:8, 11:16, 21:24, 27:32, 36:40, 44:48]
    @test FWF.scan("testfiles/test1.txt", [' ';'a':'f']) == [3:8, 11:16, 21:24, 27:32, 36:40, 44:48]
    @test FWF.scan("testfiles/test2.txt") == [1:1, 3:5]
    @test FWF.scan("testfiles/test2.txt", nrow=2) == [1:1, 3:3, 5:5]
    @test FWF.scan("testfiles/test2.txt", nrow=3) == [1:1, 3:5]
end

@testset "scan byte" begin
    @test FWF.scan("testfiles/test1.txt", UInt8(' ')) == [1:1, 3:19, 21:48]
    @test FWF.scan("testfiles/test1.txt", UInt8(' '), skip=1) == [3:8, 11:16, 21:24, 27:32, 36:40, 44:48]
    @test FWF.scan("testfiles/test2.txt", UInt8(' ')) == [1:1, 3:5]
    @test FWF.scan("testfiles/test2.txt", UInt8(' '), nrow=2) == [1:1, 3:3, 5:5]
    @test FWF.scan("testfiles/test2.txt", UInt8(' '), nrow=3) == [1:1, 3:5]
end

