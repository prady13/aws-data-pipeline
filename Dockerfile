# Use slim python image to save space (ECR Free Tier is 500MB/month)
FROM python:3.9-slim

# Set working directory
WORKDIR /var/task

# Copy requirements first to leverage Docker cache
COPY app/requirements.txt .

# Install dependencies
# Target directory is required for Lambda Container Images
RUN pip install --no-cache-dir -r requirements.txt --target "${LAMBDA_TASK_ROOT}"

# Copy function code
COPY app/main.py ${LAMBDA_TASK_ROOT}

# Set the CMD to your handler (could also be done as a parameter override outside of the Dockerfile)
CMD [ "main.lambda_handler" ]
