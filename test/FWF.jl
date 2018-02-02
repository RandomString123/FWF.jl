# Test items in FWF.jl file

# Ensure options objects get created
@testset "Options Tests" begin
    x = FWF.Options()
    @test x.usemissings == true
end