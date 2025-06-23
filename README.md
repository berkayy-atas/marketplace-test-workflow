# 📦 MyApp Backup Action

This GitHub Action performs a full mirror backup of the current repository, compresses it using **Zstandard (ZSTD)**, and uploads it to an external API using a secure activation token.

---

## 🚀 Usage

```yaml
- name: Run MyApp Backup
  uses: berkayy-atas/marketplace-test-workflow@v1.0.15
  with:
    activation_code: ${{ secrets.ACTIVATION_CODE }}
    encryption_key: ${{ secrets.ENCRYPTION_KEY }}
```

`activation_code` is **required**. It is your personal access code to the API and should be stored securely as a secret in your repository.
`encryption_key` is **required**. It is your personal encryption key for lock and open the file and should be stored securely as a secret in your repository.

---

## 🔧 Optional: Select backup modules

You can control which parts of the repository to include in the backup using optional flags:

| Name                       | Default | Description                                         |
| -------------------------- | ------- | --------------------------------------------------- |
| `backup_issues`            | `true`  | Include issues and their metadata in the backup     |
| `backup_prs`               | `true`  | Include pull requests, their branches, and comments |
| `backup_labels_milestones` | `true`  | Include repository labels and milestones            |

### Example:
Backup only repository and PRs, but skip issues and labels/milestones:

```yaml
- name: Run MyApp Backup with custom modules
  uses: berkayy-atas/marketplace-test-workflow@v1.0.15
  with:
    activation_code: ${{ secrets.ACTIVATION_CODE }}
    encryption_key: ${{ secrets.ENCRYPTION_KEY }}
    backup_issues: false
    backup_prs: true
    backup_labels_milestones: false
```


## 🔧 Optional: use_org_id

You can optionally add the `use_org_id` parameter:

```yaml
- name: Run MyApp Backup with Org ID
  uses: berkayy-atas/marketplace-test-workflow@v1.0.15
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

| Name                       | Required | Default | Description                                      |
| -------------------------- | -------- | ------- | ------------------------------------------------ |
| `activation_code`          | ✅        | –       | Activation code for the secure API.              |
| `encryption_key`           | ✅        | –       | Encryption key to securely encrypt backup files. |
| `use_org_id`               | ❌        | false   | Use organization ID instead of repository ID.    |
| `backup_issues`            | ❌        | true    | Include issues in the backup.                    |
| `backup_prs`               | ❌        | true    | Include pull requests in the backup.             |
| `backup_labels_milestones` | ❌        | true    | Include labels & milestones in the backup.       |


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
        uses: berkayy-atas/marketplace-test-workflow@v1.0.15
        with:
          activation_code: ${{ secrets.ACTIVATION_CODE }}
          encryption_key: ${{ secrets.ENCRYPTION_KEY }}
          backup_issues: true
          backup_prs: true
          backup_labels_milestones: true
          use_org_id: false
```

## 📁 What gets stored?

| Part                  | Description                                                        |
| --------------------- | ------------------------------------------------------------------ |
| **Repository mirror** | Complete bare mirror clone (`git clone --mirror`)                  |
| **Metadata**          | JSON files for issues, pull requests, comments, labels, milestones |
| **info.json**         | Stores your selected backup modules                                |
| **Encrypted archive** | `.tar.zst.enc` format, protected with your key                     |

##  🔑 How is your backup protected?

✔️ Compressed with Zstandard (ZSTD)
✔️ Encrypted with AES-256-CBC and your custom key
✔️ Uploaded securely with an API access token



