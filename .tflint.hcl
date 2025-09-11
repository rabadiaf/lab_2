# .tflint.hcl

plugin "terraform" {
  enabled = true
  # (opcional) fijá versión del ruleset
  # version = "0.13.0"
  # o preset general:
  preset  = "recommended"
}

# Habilitar explícitamente la regla de variables tipadas
rule "terraform_typed_variables" {
  enabled = true
}
