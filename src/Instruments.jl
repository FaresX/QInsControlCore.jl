struct GPIBInstr <: Instrument
    name::String
    addr::String
    geninstr::GenericInstrument
end

struct SerialInstr <: Instrument
    name::String
    addr::String
    geninstr::GenericInstrument
end

struct TCPIPInstr <: Instrument
    name::String
    addr::String
    ip::IPv4
    port::Int
    sock::Ref{TCPSocket}
    connected::Ref{Bool}
end

Base.@kwdef struct VirtualInstr <: Instrument
    name::String = "VirtualInstr"
    addr::String = "VirtualAddress"
end

function instrument(name, addr)
    if occursin("GPIB", addr)
        return GPIBInstr(name, addr, GenericInstrument())
    elseif occursin("ASRL", addr)
        return SerialInstr(name, addr, GenericInstrument())
    elseif occursin("TCPIP", addr) && occursin("SOCKET", addr)
        try
            _, ip, portstr, _ = split(addr, "::")
            port = parse(Int, portstr)
            return TCPIPInstr(name, addr, IPv4(ip), port, Ref(TCPSocket()), Ref(false))
        catch e
            @error "address is not valid" execption = e
            return GPIBInstr(name, addr, GenericInstrument())
        end
    elseif name == "VirtualInstr"
        return VirtualInstr()
    else
        return GPIBInstr(name, addr, GenericInstrument())
    end
end

Instruments.connect!(rm, instr::GPIBInstr) = connect!(rm, instr.geninstr, instr.addr)
Instruments.connect!(rm, instr::SerialInstr) = connect!(rm, instr.geninstr, instr.addr)
function Instruments.connect!(rm, instr::TCPIPInstr)
    if !instr.connected[]
        instr.sock[] = Sockets.connect(instr.ip, instr.port)
        instr.connected[] = true
    end
end
Instruments.connect!(rm, instr::VirtualInstr) = nothing
Instruments.connect!(instr::Instrument) = connect!(ResourceManager(), instr)

Instruments.disconnect!(instr::GPIBInstr) = disconnect!(instr.geninstr)
Instruments.disconnect!(instr::SerialInstr) = disconnect!(instr.geninstr)
function Instruments.disconnect!(instr::TCPIPInstr)
    if instr.connected[]
        close(instr.sock[])
        instr.connected[] = false
    end
end
Instruments.disconnect!(::VirtualInstr) = nothing

Instruments.write(instr::GPIBInstr, msg::AbstractString) = write(instr.geninstr, msg)
Instruments.write(instr::SerialInstr, msg::AbstractString) = write(instr.geninstr, string(msg, "\n"))
Instruments.write(instr::TCPIPInstr, msg::AbstractString) = println(instr.sock[], msg)
Instruments.write(::VirtualInstr, ::AbstractString) = nothing

Instruments.read(instr::GPIBInstr) = read(instr.geninstr)
Instruments.read(instr::SerialInstr) = read(instr.geninstr)
Instruments.read(instr::TCPIPInstr) = readline(instr.sock[])
Instruments.read(::VirtualInstr) = nothing

Instruments.query(instr::GPIBInstr, msg::AbstractString; delay=0) = query(instr.geninstr, msg; delay=delay)
Instruments.query(instr::SerialInstr, msg::AbstractString; delay=0) = query(instr.geninstr, string(msg, "\n"); delay=delay)
Instruments.query(instr::TCPIPInstr, msg::AbstractString; delay=0) = (println(instr.sock[], msg); sleep(delay); readline(instr.sock[]))
Instruments.query(::VirtualInstr, ::AbstractString; delay=0) = nothing