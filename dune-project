(lang dune 2.0)
(name ez-pgocaml)

(source (github ocamlpro/ez-pgocaml))
(license GPL-3.0-or-later)
(authors
 "Fabrice Le Fessant <fabrice.le_fessant@ocamlpro.com>")
(maintainers "Fabrice Le Fessant <fabrice.le_fessant@ocamlpro.com>")

(package
 (name ez-pgocaml)
 (synopsis "a simple library to work with pgocaml")
 (depends
  (pgocaml (>= 4.2.2))))
