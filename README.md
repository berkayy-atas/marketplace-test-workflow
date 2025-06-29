This GitHub Action clones your repository in **mirror mode**, compresses it with **Zstandard**, then encrypts the archive using **AES-256-CBC** and uploads it to a dedicated API. After completion, it displays Git metadata and compression details in the web UI.

---

## 📦 Setup

1. **Store your Activation Code** as a GitHub Secret  
   - Go to **Settings > Secrets > Actions** in your repository  
   - Create a new secret named `ACTIVATION_CODE`  
   - Paste in the activation code provided by your API service

2. **Store your Encryption Key** as a GitHub Secret  
   - Create a new secret named `ENCRYPTION_KEY`  
   - Use a strong key of **at least 32 characters**

3. **Add your workflow file**  
   Create a file at `.github/workflows/backup.yml` and paste in the block below:

   ```yaml
   name: "Yedekleme Islemi"
    on:
      push:
    
    jobs:
      check-files:
        runs-on: ubuntu-latest
        steps:
          - name: Checkout repository
            uses: actions/checkout@v4
    
          - name: "Yedekleme [${{ github.event_name }}] #${{ github.run_number }}: ${{ github.sha }} by ${{ github.actor }}"
            uses: berkayy-atas/marketplace-test-workflow@v1.0.19
            with:
              activation_code: ${{ secrets.ACTIVATION_CODE }}
              encryption_key: ${{ secrets.ENCRYPTION_KEY }}
     ```
---

## ⚙️ How It Works

1. **Repository Checkout**\
   Uses `actions/checkout@v4` to pull the full Git history, branches, and tags in mirror mode.

2. **Compression**

   - Archives the mirrored repo directory with `tar`
   - Compresses it with `zstd -9` to produce a `.tar.zst` file

3. **Encryption**\
   Encrypts the compressed archive by running:

   ```bash
   openssl enc -aes-256-cbc -salt -pbkdf2 \
     -in repo.tar.zst \
     -out repo.tar.zst.enc \
     -pass pass:${{ inputs.encryption_key }}
   ```

4. **API Upload**

   - Obtains an activation token via `curl`
   - Uploads the encrypted file and metadata (event type, commit info, file sizes, etc.) as `multipart/form-data` to the `/backup/shield` endpoint

5. **Web UI Metadata**\
   After upload, the web interface displays:

   - Trigger event (push, pull\_request, etc.)
   - Ref (branch or tag) and actor (who ran the workflow)
   - Commit SHA, short SHA, parent SHAs
   - Author, date, committer, commit message
   - Original archive size and encrypted file size

---

## 🔒 Technical Details

- **Backed-up Data**

  - The entire Git history (`.git` directory), including branches and tags

- **Metadata Collected**

  - Git event name, ref, actor, repository owner/type
  - Full commit details when available

- **Technologies Used**

  - Bash scripting
  - Zstandard (`zstd`) for compression
  - OpenSSL (AES-256-CBC with PBKDF2) for encryption
  - `curl` for REST API communication

- **Security**

  - `ACTIVATION_CODE` and `ENCRYPTION_KEY` are never logged—stored only in GitHub Secrets
  - Encryption key must be at least 32 characters

---

> 🔔 **Note:** This Action only handles the backup process. To restore, create a separate `restore.yml` workflow using your “Repository Restore” Action.

