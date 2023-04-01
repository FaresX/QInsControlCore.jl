struct Controller
    id::UUID
    instrnm::String
    addr::String
    databuf::Vector{String}
    Controller(instrnm, addr) = new(uuid4(), instrnm, addr, [])
end

struct Processor
    id::UUID
    controllers::Dict{UUID,Controller}
    lock::ReentrantLock
    cmdchannel::Vector{Tuple{UUID,Function,String,Val}}
    exechannels::Dict{String,Vector{Tuple{UUID,Function,String,Val}}}
    tasks::Dict{String,Task}
    taskhandlers::Dict{String,Bool}
    resourcemanager::UInt32
    instrs::Dict{String,Instrument}
    running::Ref{Bool}
    Processor() = new(uuid4(), Dict(), ReentrantLock(), [], Dict(), Dict(), Dict(), ResourceManager(), Dict(), Ref(false))
end

function login!(cpu::Processor, ct::Controller)
    push!(cpu.controllers, ct.id => ct)
    if cpu.running[]
        @warn "cpu($(cpu.id)) is running!"
        if !haskey(cpu.instrs, ct.addr)
            push!(cpu.instrs, ct.addr => instrument(ct.instrnm, ct.addr))
            push!(cpu.exechannels, ct.addr => [])
            push!(cpu.taskhandlers, ct.addr => true)
            t = @async while cpu.taskhandlers[ct.addr]
                isempty(cpu.exechannels[ct.addr]) || runcmd(cpu, popfirst!(cpu.exechannels[ct.addr])...)
                yield()
            end
            @info "task(address: $(ct.addr)) is created"
            push!(cpu.tasks, ct.addr => errormonitor(t))
            connect!(cpu.resourcemanager, cpu.instrs[ct.addr])
        end
    else
        haskey(cpu.instrs, ct.addr) || push!(cpu.instrs, ct.addr => instrument(ct.instrnm, ct.addr))
    end
    return nothing
end

function logout!(cpu::Processor, ct::Controller)
    popct = pop!(cpu.controllers, ct.id)
    if !in(popct.addr, map(ct -> ct.addr, values(cpu.controllers)))
        popinstr = pop!(cpu.instrs, ct.addr)
        if cpu.running[]
            @warn "cpu($(cpu.id)) is running!"
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

(ct::Controller)(f::Function, cpu::Processor, val::String, ::Val{:write}) = (push!(cpu.cmdchannel, (ct.id, f, val, Val(:write))); return nothing)
(ct::Controller)(f::Function, cpu::Processor, ::Val{:read}) = (push!(cpu.cmdchannel, (ct.id, f, "", Val(:read))); return nothing)
(ct::Controller)(f::Function, cpu::Processor, val::String, ::Val{:query}) = (push!(cpu.cmdchannel, (ct.id, f, val, Val(:query))); return nothing)
function (ct::Controller)(f::Function, cpu::Processor, ::Val{:waitread})
    push!(cpu.cmdchannel, (ct.id, f, "", Val(:read)))
    t1 = time()
    while isempty(ct.databuf) && time() - t1 < 6
        yield()
    end
    @assert time() - t1 < 6 "timeout"
    popfirst!(ct.databuf)
end
function (ct::Controller)(f::Function, cpu::Processor, val::String, ::Val{:waitquery})
    push!(cpu.cmdchannel, (ct.id, f, val, Val(:query)))
    t1 = time()
    while isempty(ct.databuf) && time() - t1 < 6
        yield()
    end
    @assert time() - t1 < 6 "timeout"
    popfirst!(ct.databuf)
end

Base.isready(ct::Controller) = !isempty(ct.databuf)
getdata!(ct::Controller) = popfirst!(ct.databuf)

runcmd(cpu::Processor, id::UUID, f::Function, val::String, ::Val{:write}) = (f(cpu.instrs[cpu.controllers[id].addr], val); return nothing)
runcmd(cpu::Processor, id::UUID, f::Function, ::String, ::Val{:read}) = (ct = cpu.controllers[id]; push!(ct.databuf, f(cpu.instrs[ct.addr])); return nothing)
runcmd(cpu::Processor, id::UUID, f::Function, val::String, ::Val{:query}) = (ct = cpu.controllers[id]; push!(ct.databuf, f(cpu.instrs[ct.addr], val)); return nothing)

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
                    id, f, val, type = popfirst!(cpu.cmdchannel)
                    push!(cpu.exechannels[cpu.controllers[id].addr], (id, f, val, type))
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