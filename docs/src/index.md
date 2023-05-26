```@meta
CurrentModule = QInsControlCore
```

# QInsControlCore

Documentation for [QInsControlCore](https://github.com/FaresX/QInsControlCore.jl).

This package is used to resolve conflicts when multiple coprocesses send commands to the same instrument simultaneously.
# install
before you install this package, you must make sure that you have installed the NI VISA.
```
julia> ]
(@v1.9) pkg> add https://github.com/FaresX/QInsControlCore.jl.git
```
# usage
```julia
using QInsControlCore
cpu = Processor()
ct = Controller("VirtualInstr", "VirtualAddress")
login!(cpu, ct)
start!(cpu)
idn = ct(query, cpu, "*IDN?", Val(:query))
logout!(cpu, ct)
stop!(cpu)
```

# API

```@index
```


