# Standalone fixture: render the production YAML without installing add-ons.
locals {
  eks_auto_mode = try(local.base_env.eks_auto_mode, false)
}
