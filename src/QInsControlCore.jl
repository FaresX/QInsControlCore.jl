module QInsControlCore
    using Instruments
    using Sockets
    using UUIDs

    export Controller, Processor
    export login!, logout!, start!, stop!

    include("Instruments.jl")
    include("DataStream.jl")
end # module QInsControlCore
