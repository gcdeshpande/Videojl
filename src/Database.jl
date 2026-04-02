module Database

using LibPQ
using DataFrames
using DotEnv

export get_connection, query_df

function init()
    # Load environment variables from .env file if it exists
    env_path = joinpath(@__DIR__, "..", ".env")
    if isfile(env_path)
        DotEnv.config(env_path)
    end
end

function get_connection()
    # Connect using environment variables (PGHOST, PGUSER, PGPASSWORD, PGDATABASE, PGPORT)
    # Defaulting to standard pyvideos/julia_videos DB structure if not fully specified
    host = get(ENV, "PGHOST", "127.0.0.1")
    port = get(ENV, "PGPORT", "5432")
    user = get(ENV, "PGUSER", "postgres")
    password = get(ENV, "PGPASSWORD", "theta123")
    dbname = get(ENV, "PGDATABASE", "julia_videos")
    
    conn_str = "host=$host port=$port user=$user password=$password dbname=$dbname"
    return LibPQ.Connection(conn_str)
end

function query_df(query_str::String, params::Vector=Any[])
    conn = get_connection()
    try
        if isempty(params)
            result = execute(conn, query_str)
        else
            result = execute(conn, query_str, params)
        end
        return DataFrame(result)
    finally
        close(conn)
    end
end

# Make sure to call init() when module is loaded
init()

end
