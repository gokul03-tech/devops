variable "location" {
  description = "Azure region for PeerLearn resources."
  type        = string
  default     = "Central India"
}

variable "prefix" {
  description = "Resource name prefix; use a globally unique suffix for the public IP if needed."
  type        = string
  default     = "peerlearn"
}

variable "vm_size" {
  description = "Azure VM size. B2s is recommended when Jenkins shares this VM."
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Linux administrator login name."
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Path to the administrator's OpenSSH public key."
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "Public IPv4 CIDR allowed to connect to SSH, for example 203.0.113.10/32."
  type        = string
  validation {
    condition     = can(cidrnetmask(var.allowed_ssh_cidr))
    error_message = "allowed_ssh_cidr must be a valid CIDR block."
  }
}

variable "enable_jenkins" {
  description = "Allow inbound TCP 8080 for the same-VM Jenkins installation. Restrict at the source when possible."
  type        = bool
  default     = true
}

variable "jenkins_allowed_cidrs" {
  description = "CIDR blocks allowed to reach Jenkins port 8080 (include GitHub webhook source ranges)."
  type        = list(string)
  validation {
    condition     = length(var.jenkins_allowed_cidrs) > 0 && length(distinct(var.jenkins_allowed_cidrs)) == length(var.jenkins_allowed_cidrs) && alltrue([for cidr in var.jenkins_allowed_cidrs : can(cidrnetmask(cidr))])
    error_message = "jenkins_allowed_cidrs must contain unique, valid CIDR blocks."
  }
}

variable "tags" {
  description = "Additional Azure resource tags."
  type        = map(string)
  default     = {}
}
