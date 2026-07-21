provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project            = "workhour-platform"
      Application        = "postifyhq"
      Environment        = "dev"
      Owner              = "Tope"
      ManagedBy          = "Terraform"
      ResidencyPhase     = "7"
      CostCenter         = "CloudDevOpsResidency"
      DataClassification = "none"
      Persistence        = "disposable"
    }
  }
}
