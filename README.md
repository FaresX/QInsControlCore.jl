# QInsControlCore
This package is used to resolve conflicts when multiple coprocesses send commands to the same instrument simultaneously.
# install
```
julia> ]
(@v1.9) pkg> add https://github.com/Faresx/QInsControlCore.jl.git
```
# usage
```julia
using QInsControlCore
using QInsControlCore.Instruments
cpu = Processor()
ct = Controller()
login!(cpu, ct)
start!(cpu)
idn_get(instr) = query(instr, "*IDN?")
idn = ct(idn_get, cpu, Val(:read))
logout!(cpu, ct)
stop!(cpu)
```

