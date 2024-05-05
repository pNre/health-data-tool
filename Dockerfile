FROM ocaml/opam:debian-ocaml-5.2-flambda AS env
RUN sudo apt-get update && sudo apt-get -y upgrade
RUN sudo ln -sf /usr/bin/opam-2.1 /usr/bin/opam
RUN cd opam-repository && git pull -q origin master && opam update && opam upgrade -y
RUN mkdir /home/opam/health_data_tool
WORKDIR /home/opam/health_data_tool
COPY --chown=opam ./health_data_tool.opam .
RUN opam install -y . --deps-only

FROM env AS binary
WORKDIR /home/opam/health_data_tool
COPY --chown=opam . .
RUN eval $(opam config env) && dune build --release -j$(nproc)

FROM debian:bookworm-slim AS app-env
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates procps tmux
RUN update-ca-certificates

FROM app-env AS app
COPY --from=binary /home/opam/health_data_tool/_build/install/default/bin/health_data_tool /usr/local/bin/health_data_tool
VOLUME ["/config"]
CMD ["sh", "-c", "/usr/local/bin/health_data_tool watch \"${INPUT_FOLDER}\" \"${OUTPUT_FILE}\""]
