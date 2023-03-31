using Instruments
using BenchmarkTools
f(instr, val="") = string(time())
g(instr) = ""

cpu = QInsControlCore.Processor()

ct1 = QInsControlCore.Controller("VirtualInstr", "VirtualAddress")
ct2 = QInsControlCore.Controller("VirtualInstr", "VirtualAddress")

QInsControlCore.login!(cpu, ct1)
QInsControlCore.login!(cpu, ct2)

QInsControlCore.start!(cpu)

cpu
ct1(f, cpu, "", Val(:query))
ct1(f, cpu, Val(:read))

@benchmark (ct1(f, cpu, "", Val(:query)); timedwait(()->!isempty(ct1.databuf), 1; pollint=0.001); popfirst!(ct1.databuf))

@benchmark f("s", "")

@benchmark begin
    ct1(f, cpu, "", Val(:query))
    t1 = time()
    while isempty(ct1.databuf) && time() - t1 < 1
        yield()
    end
    popfirst!(ct1.databuf)
end

@benchmark (ct1(f, cpu, "", Val(:query)); take!(ct1.databuf))

@benchmark ct1(f, cpu, "", Val(:waitquery))

empty!(ct1.databuf)
ct1.databuf

ct2(f, cpu, Val(:read))
ct2.databuf

ct3 = QInsControlCore.Controller("Triton", "TCPIP::192.168.31.239::33576::SOCKET")
QInsControlCore.login!(cpu, ct3)

@benchmark ct3(query, cpu, "*IDN?", Val(:waitquery))

@benchmark query(cpu.instrs["TCPIP::192.168.31.239::33576::SOCKET"], "*IDN?")
ct3.databuf
empty!(ct3.databuf)

ct4 = QInsControlCore.Controller("Triton", "TCPIP::192.168.31.239::33576::SOCKET")
QInsControlCore.login!(cpu, ct4)
ct4(query, cpu, "*IDN?", Val(:query))
ct4.databuf

for i in 1:10
    @async ct3(query, cpu, "*IDN?", Val(:query))
    @async ct4(query, cpu, "*IDN?", Val(:query))
end

ct4(query, cpu, "*", Val(:query))

QInsControlCore.logout!(cpu, ct1)
QInsControlCore.logout!(cpu, ct2)

cpu.controllers
cpu.cmdchannel
cpu.instrs
cpu.tasks
cpu.taskhandlers
cpu.exechannels

QInsControlCore.stop!(cpu)
cpu