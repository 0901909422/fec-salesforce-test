# Hướng dẫn Rollback Package trên Salesforce

## Khi nào cần Rollback?

- Package version mới gây lỗi trên org đích
- Cần quay lại phiên bản ổn định trước đó
- Có bug nghiêm trọng sau khi cài đặt

---

## Cách 1: Cài lại version cũ (Khuyến nghị)

Đây là cách an toàn nhất — cài đè version cũ lên version mới.

### Bước 1: Tìm version cũ cần quay lại

```bash
sf package version list --package "GitLabPipelinesPkg" --order-by CreatedDate
```

Kết quả sẽ hiện danh sách các version, ví dụ:

```
Package Name        Version   Subscriber Package Version Id  Created Date
──────────────────  ────────  ──────────────────────────────  ─────────────
GitLabPipelinesPkg  0.1.0.1   04tXXXXXXXXXXXXXX1            2025-01-10
GitLabPipelinesPkg  0.1.0.2   04tXXXXXXXXXXXXXX2            2025-01-15  ← version lỗi
```

Chọn Id của version ổn định (ở đây là `04tXXXXXXXXXXXXXX1`).

### Bước 2: Cài đè version cũ vào org

```bash
sf package install --package 04tXXXXXXXXXXXXXX1 --target-org TargetOrg --installation-key "FECCSM123" --wait 10
```

> Salesforce sẽ tự động ghi đè version hiện tại bằng version bạn chỉ định.

### Bước 3: Xác nhận rollback thành công

```bash
sf package installed list --target-org TargetOrg
```

Kiểm tra version number đã quay lại đúng version cũ.

---

## Cách 2: Gỡ hoàn toàn Package (Uninstall)

Dùng khi muốn xóa sạch package khỏi org.

### Lưu ý trước khi Uninstall

- Tất cả data liên quan đến custom objects trong package sẽ bị **XÓA VĨNH VIỄN**
- Không thể undo sau khi uninstall
- Nên backup data trước

### Bước thực hiện

```bash
sf package uninstall --package 04tXXXXXXXXXXXXXX2 --target-org TargetOrg --wait 10
```

Kiểm tra:

```bash
sf package installed list --target-org TargetOrg
```

Package sẽ không còn trong danh sách.

---

## Cách 3: Rollback qua Salesforce UI

Nếu không dùng CLI, bạn có thể thao tác trên giao diện:

1. Đăng nhập org đích
2. Vào **Setup** → tìm **"Installed Packages"**
3. Tìm package **GitLabPipelinesPkg**
4. Click **Uninstall** để gỡ hoàn toàn

Hoặc để cài version cũ qua UI:
1. Dùng link cài đặt: `https://login.salesforce.com/packaging/installPackage.apexp?p0=04tXXXXXXXXXXXXXX1`
2. Thay `04t...` bằng Subscriber Package Version Id của version cũ
3. Chọn "Install for All Users" → Install

---

## Quy trình Rollback tóm tắt

```
Phát hiện lỗi → Xác định version cũ ổn định → Cài đè version cũ (hoặc Uninstall) → Verify
```

---

## Checklist trước khi Rollback

- [ ] Xác nhận version nào đang lỗi
- [ ] Xác nhận version cũ nào ổn định
- [ ] Thông báo team trước khi rollback
- [ ] Backup data nếu cần (đặc biệt khi uninstall)
- [ ] Kiểm tra dependencies (package khác có phụ thuộc không)

---

## Lỗi thường gặp khi Rollback

| Lỗi | Nguyên nhân | Cách xử lý |
|-----|-------------|------------|
| "Cannot downgrade package" | Version cũ hơn version đang cài | Dùng `--upgrade-type Mixed` trong lệnh install |
| "Package is not installed" | Package đã bị gỡ trước đó | Cài lại bình thường bằng `sf package install` |
| "Cannot uninstall, components in use" | Có config/automation đang reference component trong package | Xóa references trước (ví dụ: Flow, Validation Rule đang dùng field của package) |

---

## Mẹo phòng tránh

- Luôn test version mới trên **Sandbox** trước khi cài Production
- Dùng `--skip-validation` khi test trên Sandbox để tiết kiệm thời gian
- Ghi chú lại version Id ổn định cuối cùng vào wiki/document của team
- Cân nhắc dùng `sf package version promote` chỉ khi đã test kỹ
