Gem::Specification.new do |s|
  s.name = "pago_efectivo"
  s.version = "1.0.0.aplha"
  s.summary = "SOAP client to use Pago Efectivo"
  s.description = s.summary
  s.authors = ["César Carruitero"]
  s.email = ["cesar@mozilla.pe"]
  s.homepage = "https://github.com/ccarruitero/pago_efectivo"
  s.license = "MPL"

  s.files = `git ls-files`.split("\n")

  s.add_runtime_dependency "gyoku", "1.1.1"
  s.add_runtime_dependency "savon", "2.6.0"

  s.add_development_dependency "cutest"
end
