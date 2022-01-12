D = Steep::Diagnostic

target :lib do
  signature 'sig'
  check 'lib', 'scripts'

  library 'uri', 'logger', 'monitor'
  library 'bbk-utils', 'bbk-app'

  configure_code_diagnostics(D::Ruby.strict)
end

