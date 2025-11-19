Serverless Data Pipeline (AWS Free Tier)

Prerequisites:
AWS Account (Free Tier eligible).

GitHub Repository containing these files.

Terraform and Docker installed locally (optional, if you want to test locally).

Setup Instructions:

Step 1: AWS Secrets

Go to your GitHub Repository -> Settings -> Secrets and Variables -> Actions.
Add the following Repository Secrets:

AWS_ACCESS_KEY_ID: Your AWS Access Key.

AWS_SECRET_ACCESS_KEY: Your AWS Secret Key.

Step 2: The "Chicken and Egg" Problem

Terraform creates the Lambda function, but the Lambda function needs a Docker image. The Docker image needs an ECR repository to live in, which Terraform creates.

How the CI/CD solves this:
Our .github/workflows/deploy.yml handles this automatically by running in two stages:

Run Terraform targeting only the ECR repository.

Build and Push the Docker image to that repository.

Run Terraform for the rest of the infrastructure (Lambda, S3).

Step 3: Deploy

Simply push your code to the main branch:

git add .
git commit -m "Initial deploy"
git push origin main


Step 4: Verify

Go to the AWS Console > Lambda. Find data-pipeline-demo-function.

Click Test -> Create a new test event -> Save -> Test.

Go to AWS Console > S3. Open the bucket data-pipeline-demo-storage-....

You should see a folder raw/YYYY-MM-DD/ containing your JSON data!

Cost Management (Free Tier)

ECR: This pipeline uses a lifecycle_policy to keep only the last 3 images, preventing you from exceeding the 500MB free storage limit.

Lambda: The script runs once a day. You have 400,000 GB-seconds free per month. This uses < 100.

Cleanup: To destroy everything and stop costs:

Empty the S3 bucket (Terraform cannot delete a non-empty bucket unless force_destroy is true, which we enabled, but be careful).

Run terraform destroy (locally) or add a destroy workflow.
