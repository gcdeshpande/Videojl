(pwd() != @__DIR__) && cd(@__DIR__) # allow starting app from bin/ dir

using JuliaVideos
const UserApp = JuliaVideos
JuliaVideos.main()
