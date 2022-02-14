/**
 * Copyright 2021 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

data "google_project" "project" {}

module "enable_google_apis" {
  source                      = "terraform-google-modules/project-factory/google//modules/project_services"
  version                     = "11.2.3"
  project_id                  = var.project_id
  activate_apis               = var.apis
  disable_services_on_destroy = false
}

resource "google_container_cluster" "gke_prod_1" {
  name     = var.cluster_1
  location = var.region_1
  enable_autopilot = true
  depends_on = [
    module.enable_google_apis
  ]
}

resource "google_container_cluster" "gke_prod_2" {
  name     = var.cluster_2
  location = var.region_2
  enable_autopilot = true
  depends_on = [
    module.enable_google_apis
  ]
}

module "gke_auth_1" {
  source       = "terraform-google-modules/kubernetes-engine/google//modules/auth"
  project_id   = var.project_id
  cluster_name = google_container_cluster.gke_prod_1.name
  location     = google_container_cluster.gke_prod_1.location
}

module "gke_auth_2" {
  source       = "terraform-google-modules/kubernetes-engine/google//modules/auth"
  project_id   = var.project_id
  cluster_name = google_container_cluster.gke_prod_2.name
  location     = google_container_cluster.gke_prod_2.location
}

resource "local_file" "gke_prod_1_kubeconfig" {
  content  = module.gke_auth_1.kubeconfig_raw
  filename = var.kubeconfig.gke_prod_1-kubeconfig
}

resource "local_file" "gke_prod_2_kubeconfig" {
  content  = module.gke_auth_2.kubeconfig_raw
  filename = var.kubeconfig.gke_prod_2-kubeconfig
}

resource "google_gke_hub_membership" "membership_1" {
  membership_id = google_container_cluster.gke_prod_1.name
  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${google_container_cluster.gke_prod_1.id}"
    }
  }
  authority {
    issuer = "https://container.googleapis.com/v1/${google_container_cluster.gke_prod_1.id}"
  }
}

resource "google_gke_hub_membership" "membership_2" {
  membership_id = google_container_cluster.gke_prod_2.name
  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${google_container_cluster.gke_prod_2.id}"
    }
  }
  authority {
    issuer = "https://container.googleapis.com/v1/${google_container_cluster.gke_prod_2.id}"
  }
}

resource "null_resource" "exec_mesh_1" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command     = "${path.module}/scripts/mesh.sh"
    environment = {
      CLUSTER        = google_gke_hub_membership.membership_1.membership_id
      LOCATION       = google_container_cluster.gke_prod_1.location
      PROJECT_ID     = var.project_id
      PROJECT_NUMBER = data.google_project.project.number
      KUBECONFIG     = "/tmp/${google_container_cluster.gke_prod_1.name}-kubeconfig"
      ASM_CHANNEL    = var.asm_channel
      ASM_LABEL      = var.asm_label
      MODULE_PATH    = path.module
    }
  }
  triggers = {
    build_number = "${timestamp()}"
    script_sha1  = sha1(file("${path.module}/scripts/mesh.sh")),
  }
}

resource "null_resource" "exec_mesh_2" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command     = "${path.module}/scripts/mesh.sh"
    environment = {
      CLUSTER        = google_gke_hub_membership.membership_2.membership_id
      LOCATION       = google_container_cluster.gke_prod_2.location
      PROJECT_ID     = var.project_id
      PROJECT_NUMBER = data.google_project.project.number
      KUBECONFIG     = "/tmp/${google_container_cluster.gke_prod_2.name}-kubeconfig"
      ASM_CHANNEL    = var.asm_channel
      ASM_LABEL      = var.asm_label
      MODULE_PATH    = path.module
    }
  }
  triggers = {
    build_number = "${timestamp()}"
    script_sha1  = sha1(file("${path.module}/scripts/mesh.sh")),
  }
}

resource "null_resource" "mesh_secret" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command     = "${path.module}/scripts/mesh_secret.sh"
    environment = {
      PROJECT     = var.project_id
      CLUSTER_1   = google_gke_hub_membership.membership_1.membership_id
      LOCATION_1  = google_container_cluster.gke_prod_1.location
      CLUSTER_2   = google_gke_hub_membership.membership_2.membership_id
      LOCATION_2  = google_container_cluster.gke_prod_2.location
    }
  }
  triggers = {
    build_number = "${timestamp()}"
    script_sha1  = sha1(file("${path.module}/scripts/mesh_secret.sh")),
  }
  depends_on = [null_resource.exec_mesh_1, null_resource.exec_mesh_2]
}

resource "null_resource" "firewall" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command     = "${path.module}/scripts/firewall.sh"
    environment = {
      PROJECT_ID     = var.project_id
    }
  }
  triggers = {
    build_number = "${timestamp()}"
    script_sha1  = sha1(file("${path.module}/scripts/firewall.sh")),
  }
  depends_on = [google_container_cluster.gke_prod_1, google_container_cluster.gke_prod_2]
}

resource "null_resource" "ob" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command     = "${path.module}/scripts/ob-app/ob.sh"
    environment = {
      PROJECT_ID = var.project_id
      CLUSTER_1  = google_gke_hub_membership.membership_1.membership_id
      LOCATION_1 = google_container_cluster.gke_prod_1.location
      CLUSTER_2  = google_gke_hub_membership.membership_2.membership_id
      LOCATION_2 = google_container_cluster.gke_prod_2.location
    }
  }
  triggers = {
    build_number = "${timestamp()}"
    script_sha1  = sha1(file("${path.module}/scripts/ob-app/ob.sh")),
  }
  depends_on = [null_resource.mesh_secret]
}

resource "null_resource" "dashboard" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command     = "${path.module}/scripts/services-dashboard.sh"
    environment = {
      PROJECT_ID = var.project_id
    }
  }
  triggers = {
    build_number = "${timestamp()}"
    script_sha1  = sha1(file("${path.module}/scripts/services-dashbaord.sh")),
  }
  depends_on = [null_resource.ob]
}