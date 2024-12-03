provider "digitalocean" {
  token = var.DIGITALOCEAN_TOKEN
}

terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }

  backend "s3" {
    endpoints = {
      s3 = "https://nyc3.digitaloceanspaces.com"
    }
    bucket                      = "bastibucket"
    key                         = "terraform.tfstate"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    region                      = "us-east-1"
  }

}

resource "digitalocean_project" "proyecto_final" {
  name        = "proyecto_final"
  description = "Creacion el proyecto en digitalocean"
  resources   = [digitalocean_droplet.dropletFinal.urn]
}

resource "digitalocean_ssh_key" "keys_shh_proyecto" {
  name       = "keys_shh_proyecto"
  public_key = file("./keys/keysFinal.pub")
}

resource "digitalocean_droplet" "dropletFinal" {
  name      = "dropletFinal"
  size      = "s-2vcpu-4gb-120gb-intel"
  image     = "ubuntu-22-04-x64"
  region    = "sfo3"
  ssh_keys  = [digitalocean_ssh_key.keys_shh_proyecto.id]
  user_data = file("./docker-install.sh")

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /projects",
      "mkdir -p /volumes/nginx/html",
      "mkdir -p /volumes/nginx/certs",
      "mkdir -p /volumes/nginx/vhostd",
      "touch /projects/.env",
      "echo \"DB_USER=${var.DB_USER}\" >> /projects/.env",
      "echo \"DB_PASSWORD=${var.DB_PASSWORD}\" >> /projects/.env",
      "echo \"DB_CLUSTER=${var.DB_CLUSTER}\" >> /projects/.env",
      "echo \"DB_NAME=${var.DB_NAME}\" >> /projects/.env",
      "echo \"DOMAIN=${var.DOMAIN}\" >> /projects/.env",
      "echo \"USER_EMAIL=${var.USER_EMAIL}\" >> /projects/.env",
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("./keys/keysFinal")
      host        = self.ipv4_address
    }
  }

  provisioner "file" {
    source      = "./containers/docker-compose.yml"
    destination = "/projects/docker-compose.yml"

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("./keys/keysFinal")
      host        = digitalocean_droplet.dropletFinal.ipv4_address
    }
  }
}


resource "time_sleep" "wait_installations" {
  depends_on      = [digitalocean_droplet.dropletFinal]
  create_duration = "130s"
}



resource "null_resource" "init_api" {
  depends_on = [time_sleep.wait_installations]
  provisioner "remote-exec" {
    inline = [
      "cd /projects",
      "docker compose up -d"  
    ]
    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("./keys/keysFinal")
      host        = digitalocean_droplet.dropletFinal.ipv4_address
    }
  }
}

output "ip" {
  value = digitalocean_droplet.dropletFinal.ipv4_address
}




# resource "null_resource" "ssh-container" {
#   depends_on = [time_sleep.wait_installations]
#   connection {
#     type        = "ssh"
#     user        = "root"
#     private_key = file("./keys/keys_yo")
#     host        = digitalocean_droplet.diegoServerDroplet.ipv4_address
#   }

#   provisioner "remote-exec" {
#     inline = ["docker container run --name=adidas -dp 80:80 nginx"]
#   }
# }


# resource "null_resource" "copiar_documento_adidas" {
#   provisioner "file" {
#     source = "./adidas"
#     destination = "/adidas"
#   } 
#   connection {
#     type = "ssh"
#     user = "root"
#     private_key = file("./keys/keys_yo")
#     host = digitalocean_droplet.diegoServerDroplet.ipv4_address
#   }
# }

# resource "null_resource" "copiar_contenedor" {
#   depends_on = [null_resource.copir_documento_adidas]

#   connection {
#     type = "ssh"
#     user = "root"
#     private_key = file("./keys/keys_yo")
#     host = digitalocean_droplet.diegoServerDroplet.ipv4_address
#   }
# }



# hace cd / (para meterte a los archivos)
# docker cp adidas/. adidas:/usr/share/nginx/html