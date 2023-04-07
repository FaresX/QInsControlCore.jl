struct Controller
    id::UUID
    instrnm::String
    addr::String
    databuf::Dict{UUID,String}
    Controller(instrnm, addr) = new(uuid4(), instrnm, addr, Dict())
end

struct Processor
    id::UUID
    controllers::Dict{UUID,Controller}
    cmdchannel::Vector{Tuple{UUID,UUID,Function,String,Val}}
    exechannels::Dict{String,Vector{Tuple{UUID,UUID,Function,String,Val}}}
    tasks::Dict{String,Task}
    taskhandlers::Dict{String,Bool}
    resourcemanager::UInt32
    instrs::Dict{String,Instrument}
    running::Ref{Bool}
    Processor() = new(uuid4(), Dict(), [], Dict(), Dict(), Dict(), ResourceManager(), Dict(), Ref(false))
end

find_resources(cpu::Processor) = Instruments.find_resources(cpu.resourcemanager)

function login!(cpu::Processor, ct::Controller)
    push!(cpu.controllers, ct.id => ct)
    if cpu.running[]
        # @warn "cpu($(cpu.id)) is running!"
        if !haskey(cpu.instrs, ct.addr)
            push!(cpu.instrs, ct.addr => instrument(ct.instrnm, ct.addr))
            push!(cpu.exechannels, ct.addr => [])
            push!(cpu.taskhandlers, ct.addr => true)
            t = @async while cpu.taskhandlers[ct.addr]
                isempty(cpu.exechannels[ct.addr]) || runcmd(cpu, popfirst!(cpu.exechannels[ct.addr])...)
                yield()
            end
            # @info "task(address: $(ct.addr)) is created"
            push!(cpu.tasks, ct.addr => errormonitor(t))
            connect!(cpu.resourcemanager, cpu.instrs[ct.addr])
        end
    else
        haskey(cpu.instrs, ct.addr) || push!(cpu.instrs, ct.addr => instrument(ct.instrnm, ct.addr))
    end
    return nothing
end

function logout!(cpu::Processor, ct::Controller)
    popct = pop!(cpu.controllers, ct.id, 1)
    popct == 1 && return nothing
    if !in(popct.addr, map(ct -> ct.addr, values(cpu.controllers)))
        popinstr = pop!(cpu.instrs, ct.addr)
        if cpu.running[]
            # @warn "cpu($(cpu.id)) is running!"
            cpu.taskhandlers[popinstr.addr] = false
            wait(cpu.tasks[popinstr.addr])
            pop!(cpu.taskhandlers, popinstr.addr)
            pop!(cpu.tasks, popinstr.addr)
            pop!(cpu.exechannels, popinstr.addr)
            disconnect!(popinstr)
        end
    end
    return nothing
end
function logout!(cpu::Processor, addr::String)
    for ct in values(cpu.controllers)
        ct.addr == addr && logout!(cpu, ct)
    end
end

function (ct::Controller)(f::Function, cpu::Processor, val::String, ::Val{:write})
    @assert haskey(cpu.controllers, ct.id) "Controller is not logged in"
    cmdid = uuid4()
    push!(cpu.cmdchannel, (ct.id, cmdid, f, val, Val(:write)))
    t1 = time()
    while !haskey(ct.databuf, cmdid) && time() - t1 < 6
        yield()
    end
    @assert haskey(ct.databuf, cmdid) "timeout"
    pop!(ct.databuf, cmdid)
end
function (ct::Controller)(f::Function, cpu::Processor, ::Val{:read})
    @assert haskey(cpu.controllers, ct.id) "Controller is not logged in"
    cmdid = uuid4()
    push!(cpu.cmdchannel, (ct.id, cmdid, f, "", Val(:read)))
    t1 = time()
    while !haskey(ct.databuf, cmdid) && time() - t1 < 6
        yield()
    end
    @assert haskey(ct.databuf, cmdid) "timeout"
    pop!(ct.databuf, cmdid)
end
function (ct::Controller)(f::Function, cpu::Processor, val::String, ::Val{:query})
    @assert haskey(cpu.controllers, ct.id) "Controller is not logged in"
    cmdid = uuid4()
    push!(cpu.cmdchannel, (ct.id, cmdid, f, val, Val(:query)))
    t1 = time()
    while !haskey(ct.databuf, cmdid) && time() - t1 < 6
        yield()
    end
    @assert haskey(ct.databuf, cmdid) "timeout"
    pop!(ct.databuf, cmdid)
end

function runcmd(cpu::Processor, ctid::UUID, cmdid::UUID, f::Function, val::String, ::Val{:write})
    ct = cpu.controllers[ctid]
    f(cpu.instrs[ct.addr], val)
    push!(ct.databuf, cmdid => "done")
    return nothing
end
function runcmd(cpu::Processor, ctid::UUID, cmdid::UUID, f::Function, ::String, ::Val{:read})
    ct = cpu.controllers[ctid]
    push!(ct.databuf, cmdid => f(cpu.instrs[ct.addr]))
    return nothing
end
function runcmd(cpu::Processor, ctid::UUID, cmdid::UUID, f::Function, val::String, ::Val{:query})
    ct = cpu.controllers[ctid]
    push!(ct.databuf, cmdid => f(cpu.instrs[ct.addr], val))
    return nothing
end

function init!(cpu::Processor)
    if !cpu.running[]
        empty!(cpu.cmdchannel)
        empty!(cpu.exechannels)
        empty!(cpu.tasks)
        empty!(cpu.taskhandlers)
        for (addr, instr) in cpu.instrs
            try
                connect!(cpu.resourcemanager, instr)
            catch e
                @error "connecting to $addr failed" exception=e
            end
            push!(cpu.exechannels, addr => [])
            push!(cpu.taskhandlers, addr => false)
        end
        cpu.running[] = false
    end
    return nothing
end

reconnect!(cpu::Processor) = connect!.(cpu.resourcemanager, values(cpu.instrs))

function run!(cpu::Processor)
    if !cpu.running[]
        cpu.running[] = true
        errormonitor(
            @async while cpu.running[]
                if !isempty(cpu.cmdchannel)
                    ctid, cmdid, f, val, type = popfirst!(cpu.cmdchannel)
                    push!(cpu.exechannels[cpu.controllers[ctid].addr], (ctid, cmdid, f, val, type))
                end
                yield()
            end
        )
        for (addr, exec) in cpu.exechannels
            cpu.taskhandlers[addr] = true
            t = @async while cpu.taskhandlers[addr]
                isempty(exec) || runcmd(cpu, popfirst!(exec)...)
                yield()
            end
            @info "task(address: $addr) is created"
            push!(cpu.tasks, addr => errormonitor(t))
        end
        errormonitor(
            @async while cpu.running[]
                for (addr, t) in cpu.tasks
                    if istaskfailed(t)
                        @warn "task(address: $addr) is failed, recreating..."
                        newt = @async while cpu.taskhandlers[addr]
                            isempty(cpu.exechannels[addr]) || runcmd(cpu, popfirst!(cpu.exechannels[addr])...)
                            yield()
                        end
                        @info "task(address: $addr) is recreated"
                        push!(cpu.tasks, addr => errormonitor(newt))
                    end
                end
                yield()
            end
        )
    end
    return nothing
end

function stop!(cpu::Processor)
    if cpu.running[]
        cpu.running[] = false
        for addr in keys(cpu.taskhandlers)
            cpu.taskhandlers[addr] = false
        end
        for t in values(cpu.tasks)
            wait(t)
        end
        empty!(cpu.taskhandlers)
        empty!(cpu.tasks)
        for instr in values(cpu.instrs)
            disconnect!(instr)
        end
    end
    return nothing
end

start!(cpu::Processor) = (init!(cpu); run!(cpu))