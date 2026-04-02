events = [
  "JuliaCon 2021",
  "JuliaCon 2020",
  "JuliaCon Global 2024",
  "Boston Meetup",
  "DjangoCon Europe 2016"
]

grouped = Dict{String, Vector{Any}}()

for name in events
    m = match(r"^(.*?)\s+((?:19|20)\d{2})$", name)
    if m !== nothing
        base_name = strip(m.captures[1])
        year = parse(Int, m.captures[2])
        
        if !haskey(grouped, base_name)
            grouped[base_name] = []
        end
        push!(grouped[base_name], Dict("full_name" => name, "year" => year))
    else
        # If no year found, the base name is the full name itself
        if !haskey(grouped, name)
            grouped[name] = []
        end
        push!(grouped[name], Dict("full_name" => name, "year" => nothing))
    end
end

for (base, matches) in grouped
    sort!(matches, by = x -> isnothing(x["year"]) ? 0 : x["year"])
    println("Base: $base -> $matches")
end
