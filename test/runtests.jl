using QInsControlCore
using Test

@testset "QInsControlCore.jl" begin
    @test_broken begin
        cpu = Processor()
        ct = Controller("VirtualInstr", "VirtualAddress")
        login!(cpu, ct)
        start!(cpu)
        str = ct(write, cpu, "*IDN?", Val(:write))
        logout!(cpu, ct)
        stop!(cpu)
        str == "done"
    end
    @test_broken begin
        cpu = Processor()
        ct = Controller("VirtualInstr", "VirtualAddress")
        login!(cpu, ct)
        start!(cpu)
        str = ct(read, cpu, Val(:read))
        logout!(cpu, ct)
        stop!(cpu)
        str == "read"
    end
    @test_broken begin
        cpu = Processor()
        ct = Controller("VirtualInstr", "VirtualAddress")
        login!(cpu, ct)
        start!(cpu)
        str = ct(query, cpu, "*IDN?", Val(:query))
        logout!(cpu, ct)
        stop!(cpu)
        str == "query"
    end
    @test_broken begin
        cpu = Processor()
        start!(cpu)
        islow = !cpu.fast[]
        stop!(cpu)
        islow
    end
    @test_broken begin
        cpu = Processor()
        start!(cpu)
        fast!(cpu)
        isfast = cpu.fast[]
        stop!(cpu)
        isfast
    end
end
