(lang dune 3.14)

(name health_data_tool)

(generate_opam_files true)

(source
 (github pNre/health-data-tool))

(authors "pNre")

(maintainers "pNre")

(license LICENSE)

(package
 (name health_data_tool)
 (synopsis "HealthKit Export XML to JSON")
 (description
  "A tool to convert the XML exported by Apple's iOS Health app to JSON in order to simplify importing in a db")
 (depends ocaml dune xmlm jsonm extunix cmdliner eio eio_main camlzip))
