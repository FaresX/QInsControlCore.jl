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
ct(query, cpu, "*IDN?", Val(:query))
while !isready(ct)
yield()
end
idn = getdata!(ct)
# or you can simply use it through
# idn = ct(query, cpu, "*IDN?", Val(:waitquery))
logout!(cpu, ct)
stop!(cpu)
```

