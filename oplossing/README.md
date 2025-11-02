# Golang Demo App Deployment on AWS with Terraform MINIMUM REQUIREMENTS

## Project Overview
Dit project deployt de **PXL Golang webapplicatie** naar een **schaalbare en fouttolerante AWS infrastructuur** met behulp van Terraform.  
De applicatie is **publiek bereikbaar via een Application Load Balancer (ALB)**, dat verkeer verdeelt over meerdere webservers in **verschillende Availability Zones**.  

Kenmerken:
- **High Availability** door meerdere AZ’s en load balancing.  
- **Fault Tolerance** door health checks en automatische failover.  
- **Veiligheid** doordat EC2-instances alleen verkeer toelaten vanaf de ALB op applicatiepoort 5000.  
- **Volledige automatisering**, inclusief automatische SSH-keypair-generatie.
---

## Architectuur
- **VPC**: `172.16.0.0/16`  
- **Public Subnets**:  
  - Public Subnet 1 (`172.16.1.0/24`, us-east-1a)  
  - Public Subnet 2 (`172.16.2.0/24`, us-east-1b)  
- **Private Subnets:**  
  - `172.16.10.0/24` (us-east-1a)  
  - `172.16.11.0/24` (us-east-1b)
- **Internet Gateway**: voor publieke toegang
- **NAT Gateway:** outbound internet voor webservers (privates).
- **Route Table**: met default route `0.0.0.0/0` via IGW  
- **Application Load Balancer:** publiek bereikbaar op poort 80 → forward naar target group (poort 5000).
- **Target Group**: health checks op `/`, status 200–399  
- **EC2 Instances** -> Nu via ASG's:  
  - 2 webservers in verschillende AZ’s  
  - Via Launch Template met userdata (Go-app installatie en systemd-service)  
- **Security Groups**:  
  - ALB SG: inbound 80 van internet, outbound 5000 naar EC2 SG  
  - EC2 SG: inbound 5000 vanaf ALB SG, outbound alles  
  - Bastion SG: enkel SSH van lokaal laptop en naar de private servers 
- **Auto Scaling Group:** 1–3 EC2-webservers verspreid over 2 AZ’s.
- **Bastion Host:** enkel via SSH bereikbaar van jouw IP, met interne toegang tot private EC2’s.



---

##  Deployment

### 1. Prerequisites
- Terraform ≥ 1.5  
- AWS CLI geconfigureerd (bijv. via AWS Academy)  
- Regio: `us-east-1`  
- Internet-toegang
- **BELANGRIJK, DIT ENKEL 1 KEER DOEN!!** Creeren van een nieuwe Key Pair op aws + lokale computer **(niet in het project folder doen)**+ **zie Stap 5** voor na terraform apply
```
aws ec2 create-key-pair --key-name my-key --query 'KeyMaterial' --output text > my-key.pem
chmod 400 my-key.pem

```

### 2. Variabelen configureren
In `terraform.tfvars`:

```hcl
my_region           = "us-east-1"
my_instance_type    = "t3.micro"
key_name            = "my-keypair"
allowed_client_cidr = "<JE-EIGEN-IP-PLAATSEN>"   # of eigen IP voor restrictie
userdata_file       = "userdata.sh"
```

### 3. Toegang tot de applicatie = SwaggerUI/Golang-App: 
Via de ALB
Check **Terraform output**
alb_dns_name = "my-alb-xxxxxxx.us-east-1.elb.amazonaws.com"
- kan veranderen als je terraform destroy of nieuwe initialiseert



### 4. Terraform Uitvoeren
- terraform init
- terraform plan
- terraform apply -auto-approve


### 5. Verbinding via SSH || Local User > Bastion > Private Servers

- Op je eigen laptop geef volgende commando's in: 
```
eval "$(ssh-agent -s)"
ssh-add my-key.pem
ssh-add -l
```
- Verbind met de Bastion vanuit lokaal pc
GEEN SUDO gebruiken
```
ssh -A -i ubuntu@<bastion-public-ip>

```
- Eenmaal op de bastion
```
ssh ubuntu@<private-server-ip>

```