# QInsControlCore

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://FaresX.github.io/QInsControlCore.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://FaresX.github.io/QInsControlCore.jl/dev/)
[![Build Status](https://github.com/FaresX/QInsControlCore.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/FaresX/QInsControlCore.jl/actions/workflows/CI.yml?query=branch%3Amaster)
[![Coverage](https://codecov.io/gh/FaresX/QInsControlCore.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/FaresX/QInsControlCore.jl)

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

