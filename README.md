# MyApp Backup Action

Yedekleme işlemini mirror modda yapar, ZSTD ile sıkıştırır, API’ye yükler.  
İsteğe bağlı olarak organization ID kullanılabilir.

## Kullanım

```yaml
- name: Backup Repo
  uses: berkayy-atas/marketplace-backup-action@v1.0.0
  with:
    icredible_activation_code: ${{ secrets.ICREDIBLE_ACTIVATION_CODE }}
    use_org_id: true  # isteğe bağlı
