using Genie.Router
using Genie.Requests
using Genie.Renderer
using Genie.Renderer.Json: json
using JSON3
using LibPQ
using DataFrames

include("src/Database.jl")

function serve_static_html(path)
  Genie.Renderer.respond(read(path, String), 200, Dict("Content-Type" => "text/html"))
end

# API Routes
route("/api/videos/:id") do
  id_param = payload(:id, params(:id, nothing))
  if id_param === nothing
      return json(Dict("error" => "No ID provided"))
  end
  
  query = """
    SELECT v.id, v.title, v.description, v.youtube_url, v.duration, v.published_at, v.year, v.language,
           e.name as event_name, s.name as speaker_name 
    FROM videos v
    LEFT JOIN events e ON v.event_id = e.id
    LEFT JOIN speakers s ON v.speaker_id = s.id
    WHERE v.id = $(id_param)
  """
  conn = Database.get_connection()
  result = execute(conn, query)
  df = DataFrame(result)
  close(conn)
  
  if nrow(df) == 0
      return json(Dict("error" => "Not found"))
  end
  
  row = df[1, :]
  return json(Dict(
      "id" => row.id,
      "title" => row.title,
      "description" => ismissing(row.description) ? "" : row.description,
      "youtube_url" => row.youtube_url,
      "duration" => ismissing(row.duration) ? 0 : row.duration,
      "published_at" => row.published_at,
      "year" => ismissing(row.year) ? "" : row.year,
      "language" => ismissing(row.language) ? "English" : row.language,
      "event_name" => ismissing(row.event_name) ? "" : row.event_name,
      "speaker_name" => ismissing(row.speaker_name) ? "" : row.speaker_name
  ))
end

route("/api/videos") do
  # Fetch latest videos with related event and speaker info
  # Optional simple filters
  event_filter = payload(:event, params(:event, ""))
  speaker_filter = payload(:speaker, params(:speaker, ""))
  lang_filter = payload(:language, params(:language, ""))
  search_filter = payload(:q, params(:q, ""))
  tag_filter = payload(:tag, params(:tag, ""))
  year_filter = payload(:year, params(:year, ""))
  
  where_clauses = ["1=1"]
  
  if event_filter != ""
      push!(where_clauses, "(e.name ILIKE '%$(event_filter)%' OR v.title ILIKE '%$(event_filter)%')")
  end
  if speaker_filter != ""
      push!(where_clauses, "s.name ILIKE '%$(speaker_filter)%'")
  end
  if lang_filter != ""
      push!(where_clauses, "v.language ILIKE '%$(lang_filter)%'")
  end
  if tag_filter != ""
      # Keyword-based tag filtering: search in title and description
      push!(where_clauses, "(v.title ILIKE '%$(tag_filter)%' OR v.description ILIKE '%$(tag_filter)%')")
  end
  if year_filter != ""
      push!(where_clauses, "CAST(v.year AS TEXT) = '$(year_filter)'")
  end
  if search_filter != ""
      push!(where_clauses, "(v.title ILIKE '%$(search_filter)%' OR v.description ILIKE '%$(search_filter)%' OR s.name ILIKE '%$(search_filter)%')")
  end

  where_stmt = join(where_clauses, " AND ")

  query = """
    SELECT v.id, v.title, v.description, v.youtube_url, v.duration, v.published_at, v.year, v.language,
           e.name as event_name, s.name as speaker_name 
    FROM videos v
    LEFT JOIN events e ON v.event_id = e.id
    LEFT JOIN speakers s ON v.speaker_id = s.id
    WHERE $where_stmt
    ORDER BY v.published_at DESC NULLS LAST
    LIMIT 200
  """
  conn = Database.get_connection()
  result = execute(conn, query)
  df = DataFrame(result)
  close(conn)

  videos = []
  for row in eachrow(df)
      push!(videos, Dict(
          "id" => row.id,
          "title" => row.title,
          "description" => ismissing(row.description) ? "" : row.description,
          "youtube_url" => row.youtube_url,
          "duration" => ismissing(row.duration) ? 0 : row.duration,
          "published_at" => row.published_at,
          "year" => ismissing(row.year) ? "" : row.year,
          "language" => ismissing(row.language) ? "English" : row.language,
          "event_name" => ismissing(row.event_name) ? "" : row.event_name,
          "speaker_name" => ismissing(row.speaker_name) ? "" : row.speaker_name
      ))
  end
  return json(videos)
end

route("/api/stats") do
  conn = Database.get_connection()
  
  # Getting counts
  videos_count = DataFrame(execute(conn, "SELECT COUNT(*) as count FROM videos"))[1, :count]
  events_count = DataFrame(execute(conn, "SELECT COUNT(*) as count FROM events"))[1, :count]
  
  close(conn)
  
  return json(Dict(
      "videos" => videos_count,
      "events" => events_count
  ))
end

route("/api/events") do
  conn = Database.get_connection()
  df = DataFrame(execute(conn, """
    SELECT e.name, e.year as event_year, COUNT(v.id) as count, MAX(v.year) as video_year
    FROM events e
    JOIN videos v ON e.id = v.event_id
    GROUP BY e.name, e.year
    ORDER BY COALESCE(e.year, MAX(v.year)) DESC NULLS LAST, e.name ASC
  """))
  close(conn)
  
  grouped_categories = Dict{String, Any}()
  
  for row in eachrow(df)
      name_str = String(row.name)
      db_year = ismissing(row.event_year) ? (ismissing(row.video_year) ? nothing : Int(row.video_year)) : Int(row.event_year)
      
      # Extract sub-group based on keywords
      sub_group = "Main"
      category = "JuliaCon"
      
      if occursin(r"(?i)Global", name_str)
          sub_group = "Global"
      elseif occursin(r"(?i)Local", name_str)
          sub_group = "Local"
      elseif occursin(r"(?i)Workshops|Podcast", name_str)
          category = "Workshops & Podcast"
          sub_group = "Default"
      elseif occursin(r"(?i)JuliaCon", name_str)
          sub_group = "Main"
      else
          continue # Skip "Unknown Event" or others
      end
      
      # Use database year if available, otherwise fallback to regex
      parsed_year = db_year
      if parsed_year === nothing
          m_year = match(r"((?:19|20)\d{2})", name_str)
          parsed_year = m_year !== nothing ? parse(Int, m_year.match) : nothing
      end
      
      if !haskey(grouped_categories, category)
          grouped_categories[category] = Dict(
              "base_name" => category,
              "subgroups" => Dict{String, Any}()
          )
      end
      
      if !haskey(grouped_categories[category]["subgroups"], sub_group)
          grouped_categories[category]["subgroups"][sub_group] = Dict(
              "name" => sub_group,
              "instances" => Dict{Union{Int, Nothing}, Any}()
          )
      end
      
      # Extract location if in brackets
      m_loc = match(r"\((.*?)\)", name_str)
      location = m_loc !== nothing ? m_loc.captures[1] : nothing
      
      # Exclude specific keywords from location
      if location !== nothing && (occursin(r"(?i)Online", location) || occursin(r"(?i)MIT", location))
          location = nothing
      end

      year_key = parsed_year
      instances = grouped_categories[category]["subgroups"][sub_group]["instances"]
      if !haskey(instances, year_key)
          instances[year_key] = Dict(
              "full_name" => name_str,
              "year" => parsed_year,
              "count" => row.count,
              "location" => location
          )
      else
          instances[year_key]["count"] += row.count
          # Keep the one with a location if available, or the cleaner name
          if (location !== nothing && instances[year_key]["location"] === nothing) || 
             (length(name_str) < length(instances[year_key]["full_name"]) && location === instances[year_key]["location"])
              instances[year_key]["full_name"] = name_str
              instances[year_key]["location"] = location
          end
      end
  end
  
  # Format as a sorted array
  events_array = []
  category_order = ["JuliaCon", "Workshops & Podcast"]
  
  for cat in category_order
      if haskey(grouped_categories, cat)
          data = grouped_categories[cat]
          
          # Sort subgroups: Main first, then alphabetic
          subgroup_list = []
          for (sg_name, sg_data) in data["subgroups"]
              instances_list = collect(values(sg_data["instances"]))
              sort!(instances_list, by = x -> isnothing(x["year"]) ? 0 : x["year"], rev=true)
              
              push!(subgroup_list, Dict(
                  "name" => sg_name,
                  "instances" => instances_list
              ))
          end
          
          # Custom subgroup sort: Main > Global > Local > Others
          sg_priority = Dict("Main" => 1, "Global" => 2, "Local" => 3, "Default" => 4)
          sort!(subgroup_list, by = x -> get(sg_priority, x["name"], 99))
          
          push!(events_array, Dict(
              "base_name" => cat,
              "subgroups" => subgroup_list
          ))
      end
  end
  
  return json(events_array)
end

route("/api/speakers") do
  conn = Database.get_connection()
  df = DataFrame(execute(conn, """
    SELECT s.name, COUNT(v.id) as count
    FROM speakers s
    LEFT JOIN videos v ON s.id = v.speaker_id
    GROUP BY s.name
    ORDER BY s.name ASC
  """))
  close(conn)
  speakers = []
  for row in eachrow(df)
      push!(speakers, Dict("name" => row.name, "count" => row.count))
  end
  return json(speakers)
end

route("/api/languages") do
  conn = Database.get_connection()
  df = DataFrame(execute(conn, """
    SELECT language, COUNT(id) as count
    FROM videos 
    WHERE language IS NOT NULL 
    GROUP BY language 
    ORDER BY language ASC
  """))
  close(conn)
  langs = []
  for row in eachrow(df)
      push!(langs, Dict("name" => row.language, "count" => row.count))
  end
  return json(langs)
end

route("/api/tags") do
  conn = Database.get_connection()
  # Fetch all tags
  df_tags = DataFrame(execute(conn, "SELECT name FROM tags ORDER BY name ASC"))
  
  tags = []
  for row in eachrow(df_tags)
      tag_name = String(row.name)
      # Keyword-based count: search in title and description
      count_res = DataFrame(execute(conn, """
          SELECT COUNT(*) as count 
          FROM videos 
          WHERE title ILIKE '%$(tag_name)%' OR description ILIKE '%$(tag_name)%'
      """))
      push!(tags, Dict("name" => tag_name, "count" => count_res[1, :count]))
  end
  close(conn)
  return json(tags)
end

# Keep existing HTML routes
route("/") do
  serve_static_html("src/view/index.html")
end

route("/index.html") do
  serve_static_html("src/view/index.html")
end

route("/video.html") do
  serve_static_html("src/view/video.html")
end

route("/speakers.html") do
  serve_static_html("src/view/speakers.html")
end

route("/tags.html") do
  serve_static_html("src/view/tags.html")
end

route("/events.html") do
  serve_static_html("src/view/events.html")
end

route("/search.html") do
  serve_static_html("src/view/search.html")
end

route("/languages.html") do
  serve_static_html("src/view/languages.html")
end

route("/archives.html") do
  serve_static_html("src/view/archives.html")
end

route("/404.html") do
  serve_static_html("src/view/404.html")
end

route("/pages/about.html") do
  serve_static_html("src/view/pages/about.html")
end

route("/pages/thank-you-contributors.html") do
  serve_static_html("src/view/pages/thank-you-contributors.html")
end

route("/pages/contribute-media.html") do
  serve_static_html("src/view/pages/contribute-media.html")
end

route("/pages/thanks-will-and-sheila.html") do
  serve_static_html("src/view/pages/thanks-will-and-sheila.html")
end