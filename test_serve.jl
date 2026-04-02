using Pkg; Pkg.activate(".")
using Genie
using Genie.Renderer.Html

try
    println(html(read("src/view/index.html", String)))
catch e
    println(e)
end
