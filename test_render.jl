using Pkg; Pkg.activate(".")
using Genie
using Genie.Renderer.Html
println(html(Genie.Renderer.filepath("index.html")))
