#!/usr/bin/env bash
# One-time GCP setup for prepvruksha-dev: Cloud Run API service, secrets and
# keyless GitHub Actions deploys (Workload Identity Federation).
#
# Safe to re-run: existing resources are kept. Every command passes --project
# explicitly, so the active gcloud configuration is never used or changed.
# Secret values are NOT set here; add them yourself (see infra/README.md).
set -euo pipefail

PROJECT=prepvruksha-dev
REGION=asia-south1
REPO=mvruksha-gravitas/prepvruksha
AR_REPO=prepvruksha
SERVICE=prepvruksha-api
RUNTIME_SA=api-runtime
DEPLOYER_SA=github-deployer
POOL=github
PROVIDER=github

P=(--project="$PROJECT")
NUMBER=$(gcloud projects describe "$PROJECT" --format='value(projectNumber)')
RUNTIME_EMAIL="$RUNTIME_SA@$PROJECT.iam.gserviceaccount.com"
DEPLOYER_EMAIL="$DEPLOYER_SA@$PROJECT.iam.gserviceaccount.com"

exists() { "$@" >/dev/null 2>&1; }

# 1. APIs (no Cloud Build: images are built in GitHub Actions).
gcloud services enable "${P[@]}" \
  run.googleapis.com artifactregistry.googleapis.com secretmanager.googleapis.com \
  iam.googleapis.com iamcredentials.googleapis.com sts.googleapis.com \
  firebasehosting.googleapis.com

# 2. Docker repository.
exists gcloud artifacts repositories describe "$AR_REPO" "${P[@]}" --location="$REGION" ||
  gcloud artifacts repositories create "$AR_REPO" "${P[@]}" --location="$REGION" \
    --repository-format=docker --description="PrepVruksha service images"

# 3. Secrets, stored only in Mumbai (CLAUDE.md rule 9). Values are added separately.
for secret in SUPABASE_SECRET_KEY OTP_HMAC_KEY; do
  exists gcloud secrets describe "$secret" "${P[@]}" ||
    gcloud secrets create "$secret" "${P[@]}" \
      --replication-policy=user-managed --locations="$REGION"
done

# 4. Runtime identity of the API: may read its two secrets, nothing else.
exists gcloud iam service-accounts describe "$RUNTIME_EMAIL" "${P[@]}" ||
  gcloud iam service-accounts create "$RUNTIME_SA" "${P[@]}" \
    --display-name="PrepVruksha API (Cloud Run runtime)"
for secret in SUPABASE_SECRET_KEY OTP_HMAC_KEY; do
  gcloud secrets add-iam-policy-binding "$secret" "${P[@]}" \
    --member="serviceAccount:$RUNTIME_EMAIL" --role=roles/secretmanager.secretAccessor \
    --condition=None >/dev/null
done

# 5. Deployer used by GitHub Actions: least access for deploying.
exists gcloud iam service-accounts describe "$DEPLOYER_EMAIL" "${P[@]}" ||
  gcloud iam service-accounts create "$DEPLOYER_SA" "${P[@]}" \
    --display-name="GitHub Actions deployer (dev)"
for role in roles/run.developer roles/firebasehosting.admin; do
  gcloud projects add-iam-policy-binding "$PROJECT" \
    --member="serviceAccount:$DEPLOYER_EMAIL" --role="$role" --condition=None >/dev/null
done
gcloud artifacts repositories add-iam-policy-binding "$AR_REPO" "${P[@]}" --location="$REGION" \
  --member="serviceAccount:$DEPLOYER_EMAIL" --role=roles/artifactregistry.writer >/dev/null
# Deploying a service that runs as api-runtime needs "act as" on it.
gcloud iam service-accounts add-iam-policy-binding "$RUNTIME_EMAIL" "${P[@]}" \
  --member="serviceAccount:$DEPLOYER_EMAIL" --role=roles/iam.serviceAccountUser >/dev/null

# 6. Keyless sign-in from GitHub Actions, only for this repo's deploy workflow on main.
exists gcloud iam workload-identity-pools describe "$POOL" "${P[@]}" --location=global ||
  gcloud iam workload-identity-pools create "$POOL" "${P[@]}" --location=global \
    --display-name="GitHub Actions"
exists gcloud iam workload-identity-pools providers describe "$PROVIDER" "${P[@]}" \
  --location=global --workload-identity-pool="$POOL" ||
  gcloud iam workload-identity-pools providers create-oidc "$PROVIDER" "${P[@]}" \
    --location=global --workload-identity-pool="$POOL" \
    --display-name="GitHub" \
    --issuer-uri="https://token.actions.githubusercontent.com" \
    --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.ref=assertion.ref,attribute.workflow_ref=assertion.workflow_ref" \
    --attribute-condition="assertion.repository == '$REPO' && assertion.ref == 'refs/heads/main' && assertion.workflow_ref.startsWith('$REPO/.github/workflows/deploy-dev.yml@')"
gcloud iam service-accounts add-iam-policy-binding "$DEPLOYER_EMAIL" "${P[@]}" \
  --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/projects/$NUMBER/locations/global/workloadIdentityPools/$POOL/attribute.repository/$REPO" \
  >/dev/null

# 7. The Cloud Run service, created once with Google's sample image and made
#    public (the API checks Supabase tokens itself). run.developer cannot change
#    IAM, so this is done here; deploys from GitHub then only update the service.
if ! exists gcloud run services describe "$SERVICE" "${P[@]}" --region="$REGION"; then
  gcloud run deploy "$SERVICE" "${P[@]}" --region="$REGION" \
    --image=us-docker.pkg.dev/cloudrun/container/hello \
    --service-account="$RUNTIME_EMAIL" --no-allow-unauthenticated \
    --min-instances=0 --max-instances=2
  gcloud run services add-iam-policy-binding "$SERVICE" "${P[@]}" --region="$REGION" \
    --member=allUsers --role=roles/run.invoker >/dev/null
fi

echo
echo "GitHub repository variables for .github/workflows/deploy-dev.yml:"
echo "  GCP_WORKLOAD_IDENTITY_PROVIDER=projects/$NUMBER/locations/global/workloadIdentityPools/$POOL/providers/$PROVIDER"
echo "  GCP_DEPLOYER_SA=$DEPLOYER_EMAIL"
echo "  API_URL=$(gcloud run services describe "$SERVICE" "${P[@]}" --region="$REGION" --format='value(status.url)')"
