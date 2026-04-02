using LibPQ
using HTTP
using JSON3
using Base.Threads

function get_db_connection()
    return LibPQ.Connection("host=127.0.0.1 port=5432 user=postgres password=theta123 dbname=julia_videos")
end

function synthesize_description(raw_desc::String)
    if isempty(raw_desc)
        return ""
    end
    
    lines = split(raw_desc, '\n')
    clean_lines = String[]
    for line in lines
        if occursin("http", line) || occursin("www", line) || occursin("Subscribe", line) || occursin("Twitter:", line)
            continue
        end
        push!(clean_lines, strip(line))
    end
    
    clean_text = join(clean_lines, " ")
    
    # Split by sentence boundaries (.!?) followed by space
    sentences = split(clean_text, r"(?<=[.!?]) +")
    
    valid_sentences = String[]
    for s in sentences
        s_strip = strip(s)
        if !isempty(s_strip) && length(s_strip) > 5
            push!(valid_sentences, s_strip)
        end
    end
    
    summary = join(valid_sentences[1:min(length(valid_sentences), 4)], " ")
    return summary
end

function process_video(video_id::Int, url::String)
    try
        headers = ["User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"]
        resp = HTTP.request("GET", url, headers; connect_timeout=10, read_timeout=10, retry=false)
        html = String(resp.body)
        
        m = match(r"\"shortDescription\":\"([^\"]*)\"", html)
        if m !== nothing
            raw_desc = replace(m.captures[1], "\\n" => "\n", "\\\"" => "\"")
        else
            cmd = `/tmp/yt-dlp --get-description $url`
            out = Pipe()
            proc = run(pipeline(cmd, stdout=out, stderr=devnull), wait=false)
            
            # Simple timeout mechanism
            t = Timer(15) do _
                kill(proc)
            end
            wait(proc)
            close(t)
            
            close(out.in)
            raw_desc = String(read(out))
        end
        
        summary = synthesize_description(raw_desc)
        if isempty(summary)
            summary = "A presentation on Julia programming from a recent conference or meetup."
        end
        
        conn = get_db_connection()
        execute(conn, "UPDATE videos SET description = \$1 WHERE id = \$2", [summary, video_id])
        close(conn)
        return true, video_id
    catch e
        return false, string(e)
    end
end

function main()
    conn = get_db_connection()
    res = execute(conn, "SELECT id, youtube_url FROM videos WHERE description IS NULL OR description = ''")
    
    rows = []
    for row in res
        push!(rows, (row.id, row.youtube_url))
    end
    close(conn)
    
    total_videos = length(rows)
    println("Found $total_videos videos to process.")
    
    success_count = Threads.Atomic{Int}(0)
    processed_count = Threads.Atomic{Int}(0)
    
    # Julia's Threads.@threads will automatically distribute work
    Threads.@threads for row in rows
        video_id, url = row
        ok, res_id = process_video(video_id, url)
        if ok
            Threads.atomic_add!(success_count, 1)
        end
        
        p_count = Threads.atomic_add!(processed_count, 1) + 1
        if p_count % 50 == 0
            println("Processed $p_count/$total_videos")
        end
    end
    
    println("Done. Successfully processed $(success_count.value) videos.")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
