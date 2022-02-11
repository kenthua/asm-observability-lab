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

variable "project_id" {
  description = "Unique identifer of the Google Cloud Project that is to be used"
  type        = string
}

variable "region_1" {
  description = "Google Cloud Region in which the GKE clusters are provisioned"
  type        = string
  default = "us-west1"
}

variable "region_2" {
  description = "Google Cloud Region in which the GKE clusters are provisioned"
  type        = string
  default = "us-central1"
}

variable "apis" {
  description = "List of Google Cloud APIs to be enabled for this lab"
  type        = list(string)
  default = [
    "container.googleapis.com",
    "stackdriver.googleapis.com",
    "monitoring.googleapis.com",
    "cloudtrace.googleapis.com",
    "logging.googleapis.com",
    "meshca.googleapis.com",
    "meshtelemetry.googleapis.com",
    "meshconfig.googleapis.com",
    "multiclustermetering.googleapis.com",
    "iamcredentials.googleapis.com",
    "iam.googleapis.com",
    "gkeconnect.googleapis.com",
    "gkehub.googleapis.com",
    "compute.googleapis.com",
  ]
}

variable "gke_prod_1" {
    description = "GKE prod cluster name"
    type        = string
    default = "gke-prod-1"
}

variable "gke_prod_2" {
    description = "GKE prod cluster name"
    type        = string
    default = "gke-prod-2"
}

variable "kubeconfig" {
  type = object({
    gke_prod_1-kubeconfig = string
    gke_prod_2-kubeconfig = string
  })
  default = {
    gke_prod_1-kubeconfig = "/tmp/gke-prod_1-kubeconfig"
    gke_prod_2-kubeconfig = "/tmp/gke-prod_2-kubeconfig"
  }
}

variable "asm_channel" {
    description = "ASM release channel"
    type        = string
    default = "regular"
}

variable "asm_label" {
    description = "ASM revision label"
    type        = string
    default = "asm-managed"
}

