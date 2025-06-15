# 📦 MyApp Backup Action

This GitHub Action performs a full mirror backup of the current repository, compresses it using **Zstandard (ZSTD)**, and uploads it to an external API using a secure activation token.

---

## 🚀 Usage

```yaml
- name: Run MyApp Backup
  uses: berkayy-atas/marketplace-test-workflow@latest
  with:
    activation_code: ${{ secrets.ACTIVATION_CODE }}
    encryption_key: ${{ secrets.ENCRYPTION_KEY }}
```

`activation_code` is **required**. It is your personal access code to the API and should be stored securely as a secret in your repository.

---

## 🔧 Optional: use_org_id

You can optionally add the `use_org_id` parameter:

```yaml
- name: Run MyApp Backup with Org ID
  uses: berkayy-atas/marketplace-test-workflow@latest
  with:
    activation_code: ${{ secrets.ACTIVATION_CODE }}
    encryption_key: ${{ secrets.ENCRYPTION_KEY }}
    use_org_id: true
```

### What does `use_org_id` do?
- If omitted or set to `false`, the action uses the **repository ID** as the unique identifier.
  - This means **each repository** will be treated as a separate **endpoint**.
- If set to `true`, the action retrieves the **organization ID** instead.
  - This causes **all repositories** under the organization to be considered **a single endpoint** by the external system.

**Default:** `false`

---

## 📂 Inputs

| Name                       | Required | Default | Description                                                                 |
|----------------------------|----------|---------|-----------------------------------------------------------------------------|
| `activation_code` | ✅       | –       | Activation code used to authenticate with the external API.                |
| `encryption_key` | ✅       | –       | Encryption key encrypts files with a key you specify before they are shielded.                |
| `use_org_id`              | ❌       | false   | Use organization ID instead of repo ID to unify multiple repo backups.     |

---

## ✅ Features

- ✅ Full `git clone --mirror` for accurate history
- ✅ ZSTD compression for efficient storage
- ✅ Secure token retrieval and API upload
- ✅ Supports organization-wide endpoint grouping


```yaml
name: MyApp

on:
  push:
    # branches:
    #   - main

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
