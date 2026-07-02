# Terraform Oracle Cloud Infrastructure Free Tier

![Terraform](https://img.shields.io/badge/Terraform-1.15+-623CE4?logo=terraform)
![OCI Provider](https://img.shields.io/badge/OCI%20Provider-8.19-F80000)
![Terraform validate](https://github.com/kepuvv/oci-free-tier-terraform/actions/workflows/terraform-validate.yml/badge.svg)

## Deploy Always Free Instances

Terraform configuration for deploying Oracle Cloud Free Tier virtual machines, including automatic Ansible inventory generation.

This repo will deploy:
- default VCN with default subnet
- default port 22 open
- optional security groups for choosen ports
- VMs for Oracle Free Tier like:
  - two **VM.Standard.E2.1.Micro** instances allowed by the Oracle free tier.
  - one **VM.Standard.A1.Flex** with 24GB RAM, 4 OCPUs allowed by the Oracle free tier.

```
Terraform
├── root module
│   ├── main.tf
│   ├── outputs.tf
│   ├── variables.tf
|   ├── terraform.tfvars
│   └── oci-vm-module
│       ├── network.tf
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
```

>[!NOTE]
**Actual information about Free resourses**  https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm

All you need is an empty account.

# Steps to deploy

## Step 1. Create API key

```sh
# if you want the password protected key
openssl genrsa -out ~/.ssh/not_ssh_oci_api_key.pem -aes128 2048
# if you want the non-password protected key
#openssl genrsa -out ~/.ssh/not_ssh_oci_api_key.pem 2048
chmod go-rwx ~/.ssh/not_ssh_oci_api_key.pem
openssl rsa -pubout -in ~/.ssh/not_ssh_oci_api_key.pem -out ~/.ssh/not_ssh_oci_api_key_public.pem
```

Or follow here: https://docs.oracle.com/en-us/iaas/Content/API/Concepts/apisigningkey.htm

### Install Command Line Interface (CLI)

```sh
brew install oci-cli
```

>[!NOTE]
Remember your **user**, **tenancy** and **region** , they will need to go into terraform variables.

>[!NOTE]
**tenancy-ocid** == **compartment_id**

You can get it by:

```sh
oci iam user list | jq -r '.data[] | ."compartment-id"'
```

## Step 2.  Add your variables

Create a `terraform.tfvars` file from the `terraform.tfvars.example`

```sh
cp terraform.tfvars.example terraform.tfvars
```

More info on how to gather these ids: https://docs.oracle.com/en-us/iaas/developer-tutorials/tutorials/tf-compute/01-summary.htm

## Step 3. Deploy

```sh
terraform init
terraform plan
terraform apply
```

At the end, terraform will generate an ansible inventory file ready for use in `./ansible`

## Want to store terraform state on the cloud bucket?

### Create an OCI Object Storage bucket first

Set your values:

```sh
export OCI_COMPARTMENT_OCID="ocid1.tenancy.oc1..CHANGEME"
export TF_STATE_BUCKET="bucket-name-CHANGEME"
```

Get the Object Storage namespace:

```sh
export OCI_NAMESPACE="$(oci os ns get --query 'data' --raw-output)"
```

Create the bucket:

```sh
oci os bucket create \
  --compartment-id "$OCI_COMPARTMENT_OCID" \
  --namespace-name "$OCI_NAMESPACE" \
  --name "$TF_STATE_BUCKET" \
  --public-access-type NoPublicAccess \
  --storage-tier Standard
```

Enable versioning for safer state recovery:

```sh
oci os bucket update \
  --namespace-name "$OCI_NAMESPACE" \
  --name "$TF_STATE_BUCKET" \
  --versioning Enabled
```

### Create AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY

OCI's Terraform S3 backend uses the S3-compatible Object Storage API. Create a Customer Secret Key for your OCI user:

```sh
oci iam customer-secret-key create --display-name display-name --user-id ocid1.user.oc1..CHANGEME
```

Copy the ID (**AWS_ACCESS_KEY_ID**) and the key (**AWS_SECRET_ACCESS_KEY**) to somewhere secure to be used later to set environment variables.

Put it into `~/.aws/credentials`:
```ini
[oracle]
aws_access_key_id = <customer-secret-key-id>
aws_secret_access_key = <customer-secret-key-secret>
```
>[!INFO]
https://docs.oracle.com/en/learn/ocios-s3-api-cpp/#task-2-determine-your-tenancy-namespace-and-s3-api-compartment

Create your backend config from the example:

```sh
cp backend.s3.tfbackend.example backend.s3.tfbackend
```

Uncomment `backend "s3" {}` in `main.tf`
 
>[!NOTE]
To avoid error with ignoring `skip_s3_checksum = true` in `backend.s3.tfbackend` file like:

>[!CAUTION]
Error:
│ "s3" backend:
│     failed to upload state: operation error S3: PutObject, https response error StatusCode: 501, api error NotImplemented: AWS chunked encoding not supported.

add AWS_REQUEST_CHECKSUM_CALCULATION and AWS_RESPONSE_CHECKSUM_VALIDATION environment variables:

```sh
export AWS_REQUEST_CHECKSUM_CALCULATION=when_required
export AWS_RESPONSE_CHECKSUM_VALIDATION=when_required
```

Then initialize or migrate Terraform state:

```sh
terraform init -reconfigure -backend-config=backend.s3.tfbackend
```

If you already have local state and want to move it into the bucket:

```sh
terraform init -migrate-state -backend-config=backend.s3.tfbackend
```

Do not commit `backend.s3.tfbackend` if it contains real bucket/account details.

>[!NOTE]
20GB of storage buckets are free.
