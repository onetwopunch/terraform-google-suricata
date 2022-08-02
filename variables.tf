variable "project" {
  description = "Project Id for the resources"
  type        = string
}
variable "network" {
  description = "Self link of the network on which Suricata will be deployed and will monitor"
  type        = string
}

variable "subnet" {
  description = "Self link of the subnet on which Suricata will be deployed"
  type        = string
}

variable "region" {
  description = "Region for Suricata. Must match the zone of the subnet"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zone for Suricata. Must match the zone of the subnet"
  type        = string
  default     = "us-central1-a"
}

variable "vm_source_image" {
  description = "Source image for the Suricata VM"
  type        = string
  default     = "debian-cloud/debian-10"
}

variable "custom_rules_path" {
  description = "GCS bucket path for Suricata .rules file. i.e gs://my-bucket/my.rules"
  type        = string
  default     = ""
}

variable "enable_fast_export" {
  description = "If true, logs from /var/log/suricata/fast.log will be parsed and sent to Cloud Logging. These only include alerts."
  type        = bool
  default     = true
}

variable "enable_eve_export" {
  description = "If true, logs from /var/log/suricata/eve.json will be parsed and sent to Cloud Logging. Note that these are much more chatty and include stats and traffic."
  type        = bool
  default     = false
}

variable "suricata_config_path" {
  description = "A file path to a suricata.yaml file that you would like to override the default."
  type        = string
  default     = ""
}
variable "prefix" {
  description = "Prefix of all resource names"

  default = "suricata"
  type    = string
}

variable "target_tags" {
  description = "Target tags that will be mirrored"

  default = []
  type    = list(string)
}

variable "target_subnets" {
  description = "Target subnets that will be mirrored"
  default     = []
  type        = list(string)
}

variable "target_instances" {
  description = "Target instances that will be mirrored"
  default     = []
  type        = list(string)
}

variable "filter" {
  description = "Filter configuration for packet mirroring"
  type = object({
    ip_protocols = list(string)
    cidr_ranges  = list(string)
    direction    = string
  })
  default = {
    ip_protocols = ["tcp", "udp", "icmp"]
    cidr_ranges  = ["0.0.0.0/0"]
    direction    = "BOTH"
  }
}

variable "base_priority" {
  description = <<EOF
To make the IDS work with packet mirroring, we need to allow all ports access. However, we still don't want to allow SSH from anyhere.
To solve this, we have 3 firewall rules with increasing priority. The first allows all access, the second denies SSH, the third allows
SSH only from the IAP range. This value is the base priority, which is incremented for each rule.
EOF
  type        = number
  default     = 1000
}
