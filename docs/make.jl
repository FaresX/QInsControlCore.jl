using QInsControlCore
using Documenter

DocMeta.setdocmeta!(QInsControlCore, :DocTestSetup, :(using QInsControlCore); recursive=true)

makedocs(;
    modules=[QInsControlCore],
    authors="FaresX <fyzxst@sina.com> and contributors",
    repo="https://github.com/FaresX/QInsControlCore.jl/blob/{commit}{path}#{line}",
    sitename="QInsControlCore.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://FaresX.github.io/QInsControlCore.jl",
        edit_link="master",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/FaresX/QInsControlCore.jl.git",
    devbranch="master",
)
