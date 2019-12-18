consul {
  address = "localhost:8500"
  retry {
        enabled = true
        attempts = 12
        backoff = "250ms"
    }
}
template {
    source      = "/etc/consul-template.d/nginx.conf.ctmpl"
    destination = "/etc/nginx/sites-available/default"
    perms = 0600
    command = "service nginx reload"
}
