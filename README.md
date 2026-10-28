# auto-ec2-deploy

## CI/CD setup

The workflow `.github/workflows/deploy.yaml` runs on every push to `develop`: Terraform plan/apply, then Maven build. EC2 deploy is a placeholder.

### 1. AWS

1. **OIDC provider** (IAM → Identity providers): URL `https://token.actions.githubusercontent.com`, audience `sts.amazonaws.com`.
2. **IAM role** with this trust policy (replace `<ACCOUNT_ID>`):
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Effect": "Allow",
       "Principal": {"Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"},
       "Action": "sts:AssumeRoleWithWebIdentity",
       "Condition": {
         "StringEquals": {"token.actions.githubusercontent.com:aud": "sts.amazonaws.com"},
         "StringLike": {"token.actions.githubusercontent.com:sub": "repo:<REPO_NAME>/auto-ec2-deploy:ref:refs/heads/develop"}
       }
     }]
   }
   ```
3. **Role permissions**: SSM parameter access (`ssm:*Parameter*`, `ssm:AddTagsToResource`, `ssm:ListTagsForResource`) and read/write on the state bucket.
4. **S3 bucket** (created manually, once) to store the Terraform state.

### 2. GitHub

Settings → Secrets and variables → Actions → **Variables** → *Repository variables*:

| Variable | Value |
|---|---|
| `ENABLE_PIPELINE` | `true` to enable the whole pipeline (anything else disables it) |
| `ENABLE_RUN_TERRAFORM` | `true` to enable the Terraform job (off by default) |
| `DEPLOY_TO_EC2` | `true` to enable the deploy job (off by default) |
| `AWS_ROLE_ARN` | ARN of the IAM role above |
| `TF_STATE_BUCKET` | Name of the S3 state bucket |

No AWS secrets are needed.
