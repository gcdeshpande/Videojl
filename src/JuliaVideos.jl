module JuliaVideos

using Genie

const up = Genie.up
export up

function main()
  include(joinpath(@__DIR__, "..", "routes.jl"))
  Genie.genie(; context = @__MODULE__)
end

end
