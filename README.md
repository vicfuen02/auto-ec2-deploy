# auto-ec2-deploy

## Docker setup

Running docker and executing terraform in container
   ```
   docker compose -f ./docker-compose-aws.yml up
   docker exec -it terraform sh
   terraform init \
      -backend-config="bucket=bucket_name" \
       -backend-config="key=bucket_key" \
       -backend-config="region=bucket_region"
   ```

Policy for aws IAM User using terraform to access S3 bucket for terraform state file
   ```
   {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "TerraformStateBucketAccess",
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetBucketVersioning"
            ],
            "Resource": "arn:s3:bucket"
        },
        {
            "Sid": "TerraformStateObjectAccess",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Resource": "arn:s3:bucket/*"
        }
    ]
}
   ```

Policy for aws IAM User using terraform to create ec2 terraform test resource ssm
   ```
   {
    "Version": "2012-10-17",
    "Statement": [
           {
               "Sid": "ssmAccess1",
               "Effect": "Allow",
               "Action": [
                   "ssm:PutParameter",
                   "ssm:GetParameter"
               ],
               "Resource": [
                   "arn:aws:ssm:user/smoke-test"
               ]
           },
           {
               "Sid": "SsmAccess2",
               "Effect": "Allow",
               "Action": [
                   "ssm:DescribeParameters"
               ],
               "Resource": [
                   "arn:aws:ssm:user:*"
               ]
           }
       ]
   }
   
   ```




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


