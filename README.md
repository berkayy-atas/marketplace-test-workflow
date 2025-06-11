# MyApp Backup Action

A GitHub Action that performs a mirror backup of your repository, compresses it using Zstandard (ZSTD), and uploads it to a remote API with authentication.

This action allows you to optionally send your organization ID instead of the repository ID during the activation request.

---

## 🚀 Features
- Mirror clone of your repository
- ZSTD compression for optimal backup size
- API upload with activation token
- Option to use GitHub Organization ID or Repository ID (default)

---

## 🔧 Inputs

| Name                      | Required | Default | Description                                                                 |
|---------------------------|----------|---------|-----------------------------------------------------------------------------|
| `icredible_activation_code` | ✅       | —       | The activation code used to request a token from the API.                  |
| `use_org_id`             | ❌       | `false` | Set to `true` to send your organization's numeric ID instead of repository ID. |

---

## 📦 Usage

```yaml
- name: Backup with MyApp
  uses: berkayy-atas/marketplace-test-workflow@v1.0.0
  with:
    icredible_activation_code: ${{ secrets.ICREDIBLE_ACTIVATION_CODE }}
    use_org_id: true # optional, defaults to false
```

---

## 🧠 What does `use_org_id` do?

By default, the action sends your repository's numeric ID as `uniqueId` to the API during activation. However, if you want to use your organization's ID instead (e.g. for centralized backup policies), set:

```yaml
use_org_id: true
```

This triggers an API call to GitHub to retrieve the organization ID using the built-in `GITHUB_TOKEN`.

---

## 📄 License
MIT
