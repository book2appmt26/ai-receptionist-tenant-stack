# tenant-entra — App registration in client Entra + federated credential
# bound to our AKS SA. EPIC-2 task 2.8. Skeleton.

terraform {
  required_providers {
    azuread = { source = "hashicorp/azuread" }
  }
}
