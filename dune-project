(lang dune 3.17)

(name choku)

(generate_opam_files true)

(source
 (github dakatsuka/choku))

(authors "Dai Akatsuka")

(maintainers "Dai Akatsuka")

(license MIT)

(package
 (name choku)
 (synopsis "A pure Eio HTTP server for OCaml 5")
 (description
  "Choku is an OCaml 5 HTTP server project designed around Eio-native direct-style IO.")
 (depends
  (ocaml
   (>= 5.4))
  (dune
   (>= 3.17))
  (eio
   (>= 1.0))
  (eio_main
   (>= 1.0))
  (tls
   (>= 2.0.4))
  (tls-eio
   (>= 2.0.4))
  (ca-certs
   (>= 1.0.3))
  (x509
   (>= 1.0.6))
  (domain-name
   (>= 0.5.0))
  (ptime
   (>= 1.2.0))
  (alcotest
   :with-test)
  (mirage-crypto-rng
   :with-test)
  (ocamlformat
   :with-dev-setup)))
