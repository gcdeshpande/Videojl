FROM julia:1.9

WORKDIR /app

COPY . .

RUN julia --project=. -e "using Pkg; Pkg.instantiate(); Pkg.precompile()"

ENV JULIA_NUM_THREADS=1
ENV PORT=8000

EXPOSE 8000

CMD ["bash", "bin/server"]
FROM julia:1.9

WORKDIR /app

COPY . .

RUN julia --project=. -e "using Pkg; Pkg.instantiate()"

ENV PORT=8000

EXPOSE 8000

CMD ["bash", "bin/server"]









