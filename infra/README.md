terraform init
terraform plan
terraform apply -auto-approve




🧩 Optie 1 — Gebruik GitHub Secrets (makkelijkste manier)
🔹 Stap 1: Open de repository settings

Ga op GitHub naar jouw repo, bijv.
https://github.com/<jouw-gebruikersnaam>/todoapp-clouddeploy-MorenoDamiaensPXL

Klik bovenaan op Settings.

Links in het menu kies je Secrets and variables → Actions.

Klik op New repository secret.

🔹 Stap 2: Voeg deze 3 secrets toe
Secret naam	Waarde (uit AWS IAM)	Opmerking
AWS_ACCESS_KEY_ID	bijv. AKIAIOSFODNN7EXAMPLE	van jouw AWS user
AWS_SECRET_ACCESS_KEY	bijv. wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY	ook uit AWS
(optioneel) AWS_SESSION_TOKEN	alleen als je tijdelijke credentials gebruikt (bv. van AWS Educate of SSO)