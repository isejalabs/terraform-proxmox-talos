variable "cert" {
  type = object({
    certificate_path = string
    key_path         = string
  })
}
