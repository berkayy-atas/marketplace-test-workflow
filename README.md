# 📦 MyApp Backup Action

This GitHub Action performs a full mirror backup of the current repository, compresses it using **Zstandard (ZSTD)**, and uploads it to an external API using a secure activation token.

---

## ✅ Features

- ✅ Full `git clone --mirror` for accurate history
- ✅ ZSTD compression for efficient storage
- ✅ Secure token retrieval and API upload
- ✅ Supports organization-wide endpoint grouping


```yaml
name: "Yedekleme Islemi [${{ github.event_name }}]"

on:
  push:

jobs:
  backup:
    runs-on: ubuntu-latest
    steps:
      - name: Run MyApp Backup
        uses: berkayy-atas/marketplace-test-workflow@latest
        with:
          activation_code: ${{ secrets.ACTIVATION_CODE }}
          encryption_key: ${{ secrets.ENCRYPTION_KEY }}
          
```

## 📁 What gets stored?

| Part                  | Description                                                        |
| --------------------- | ------------------------------------------------------------------ |
| **Repository mirror** | Complete bare mirror clone (`git clone --mirror`)                  |
| **Metadata**          | JSON files for commit, event, author                               |
| **Encrypted archive** | `.tar.zst.enc` format, protected with your key                     |

##  🔑 How is your backup protected?

✔️ Compressed with Zstandard (ZSTD)
✔️ Encrypted with AES-256-CBC and your custom key
✔️ Uploaded securely with an API access token



