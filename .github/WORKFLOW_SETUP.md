# GitHub Actions Setup Guide

## Prerequisites

### 1. Google Drive Access
The workflows can automatically download Python scripts from your Google Drive folder.

**Your Folder ID:** `1eDc90JiHQLD5GpaiEpcJyAMg4KRlK7Y8`

### 2. RunPod Configuration

To use the training workflows, you need:

1. **RunPod API Key**
   - Go to [runpod.io](https://www.runpod.io)
   - Navigate to **Settings** → **API Keys**
   - Create a new API key

2. **RunPod Endpoint ID**
   - Go to **Serverless Endpoints** in your RunPod dashboard
   - Create or select an endpoint for your training image
   - Copy the **Endpoint ID**

## Setting Up GitHub Secrets

1. Go to your repository: `https://github.com/IbrahimAnaz/MuRMuR`
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**

### Add These Secrets:

| Secret Name | Value | Notes |
|---|---|---|
| `RUNPOD_API_KEY` | Your RunPod API key | Keep this confidential |
| `RUNPOD_ENDPOINT_ID` | Your RunPod endpoint ID | Find in RunPod dashboard |

## Using the Workflows

### Workflow 1: Download from Google Drive

**Trigger:** Manually or on push (uncomment in workflow file)

```bash
# Via GitHub UI:
# 1. Go to Actions → Download from Google Drive
# 2. Click "Run workflow"
# 3. Enter the folder ID (pre-filled: 1eDc90JiHQLD5GpaiEpcJyAMg4KRlK7Y8)
```

This workflow:
- ✅ Downloads all Python scripts from your Google Drive folder
- ✅ Commits them to `python/` directory
- ✅ Pushes changes to the repository

### Workflow 2: RunPod Training

**Trigger:** Manual dispatch via GitHub Actions UI

```bash
# Via GitHub UI:
# 1. Go to Actions → RunPod Training
# 2. Click "Run workflow"
# 3. Fill in the parameters:
#    - Job Name: Your training job identifier
#    - Epochs: Number of training iterations
#    - Batch Size: Training batch size
#    - Learning Rate: Model learning rate
#    - GPU Type: A40, A100, H100, RTX4090, etc.
# 4. Click "Run workflow"
```

The workflow will:
- ✅ Validate your RunPod credentials
- ✅ Trigger a training job on RunPod
- ✅ Poll status until completion
- ✅ Report results in the workflow summary

## Your Python Training Script

Ensure your main training script is:
- Located in `python/` directory
- Named or callable as `train.py` (or update the workflow)
- Accepts command-line arguments for hyperparameters
- Saves outputs to a persistent location (e.g., S3, network volume)

### Example Structure:
```
python/
├── train.py           # Main training entry point
├── requirements.txt   # Python dependencies
├── utils/
│   ├── __init__.py
│   └── helpers.py
└── models/
    └── model.py
```

## Troubleshooting

### "RUNPOD_API_KEY secret not set"
→ Add the secret to Settings → Secrets and variables → Actions

### "Job failed on RunPod"
→ Check your RunPod endpoint logs in the RunPod dashboard

### "Files didn't download from Google Drive"
→ Verify the folder is shared and the folder ID is correct

### "Workflow stuck on polling"
→ Your job may still be running. Check the RunPod dashboard directly.

## Next Steps

1. ✅ Add your Python training scripts to the `python/` directory
2. ✅ Update `python/requirements.txt` with dependencies
3. ✅ Test locally: `pip install -r python/requirements.txt && python python/train.py`
4. ✅ Set RunPod secrets in GitHub
5. ✅ Trigger the **Download from Google Drive** workflow
6. ✅ Trigger the **RunPod Training** workflow to start a job

---

**Questions?** Check RunPod docs: https://docs.runpod.io
