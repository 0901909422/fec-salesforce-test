# Hướng dẫn Deploy bằng Salesforce Unlocked Package

## Tổng quan

Dự án này sử dụng **Unlocked Package** để deploy code lên Salesforce org. Thay vì push trực tiếp metadata, ta đóng gói code thành một "package version" rồi cài vào org đích.

**Ưu điểm:**
- Quản lý version rõ ràng
- Dễ rollback khi có lỗi
- Cài được vào nhiều org khác nhau
- Phù hợp với CI/CD pipeline

---

## Yêu cầu

- [Salesforce CLI (sf)](https://developer.salesforce.com/tools/salesforcecli) đã cài đặt
- Một **Dev Hub org** đã được enable (xem hướng dẫn bên dưới)
- Đã authorize Dev Hub org trên máy (xem hướng dẫn bên dưới)

---

## Bước 0: Enable Dev Hub và Authorize

### Dev Hub là gì?

Dev Hub là một tính năng trong Salesforce org cho phép bạn tạo và quản lý Unlocked Package, Scratch Org. Thường thì org **Production** hoặc **Developer Edition** sẽ được dùng làm Dev Hub.

### 0.1 Enable Dev Hub trong org

1. Đăng nhập vào org bạn muốn dùng làm Dev Hub (thường là Production hoặc Developer Edition)
2. Vào **Setup** (biểu tượng bánh răng → Setup)
3. Tìm kiếm **"Dev Hub"** trong ô Quick Find (bên trái)
4. Click vào **Dev Hub**
5. Bật toggle **Enable Dev Hub** sang ON
6. Nếu có thêm toggle **Enable Unlocked Packages and Second-Generation Managed Packages** → bật luôn

> **Lưu ý:**
> - Chỉ user có profile **System Administrator** mới thấy setting này
> - Sau khi enable, **không thể disable lại** được
> - Nếu bạn không có Production org, tạo free Developer Edition tại: https://developer.salesforce.com/signup

### 0.2 Authorize Dev Hub trên máy local

Mở terminal và chạy:

```bash
sf org login web --set-default-dev-hub --alias MyDevHub
```

**Chuyện gì sẽ xảy ra:**
1. Trình duyệt tự động mở trang đăng nhập Salesforce
2. Bạn đăng nhập bằng tài khoản **admin** của org đã enable Dev Hub
3. Click **Allow** để cấp quyền cho SF CLI
4. Trình duyệt hiện "Authentication Successful" → quay lại terminal

**Kiểm tra authorize thành công:**

```bash
sf org list
```

Bạn sẽ thấy org hiện trong danh sách với cột `(D)` đánh dấu là Dev Hub:

```
=== Orgs

 ALIAS      USERNAME                  ORG ID             STATUS
 ────────── ───────────────────────── ────────────────── ────────
 (D) MyDevHub  admin@mycompany.com   00DXXXXXXXXXXXXXXX Connected
```

> **Mẹo:** Lệnh authorize chỉ cần chạy **1 lần**. Sau đó SF CLI sẽ nhớ thông tin đăng nhập cho đến khi token hết hạn (thường vài tháng). Nếu bị hết hạn, chạy lại lệnh trên.

### Xử lý lỗi khi authorize

| Lỗi | Nguyên nhân | Cách sửa |
|-----|-------------|----------|
| "ERROR running org:login:web" | Trình duyệt không mở được | Thêm `--browser chrome` vào lệnh |
| "This org does not have Dev Hub enabled" | Chưa bật Dev Hub | Quay lại bước 0.1 |
| "INVALID_LOGIN" | Sai tài khoản/mật khẩu | Đảm bảo đăng nhập đúng org đã enable Dev Hub |

---

## Bước 1: Authorize Dev Hub

Đăng nhập vào Dev Hub org (chỉ cần làm 1 lần):

```bash
sf org login web --set-default-dev-hub --alias MyDevHub
```

Trình duyệt sẽ mở ra, bạn đăng nhập bằng tài khoản có quyền Dev Hub.

---

## Bước 2: Tạo Package Version

Chạy lệnh sau để tạo một version mới từ code hiện tại:

```bash
sf package version create --package "GitLabPipelinesPkg" --installation-key "FECCSM123" --wait 10
```

**Giải thích:**
- `--package` : Tên package (đã khai báo trong `sfdx-project.json`)
- `--installation-key` : Mật khẩu để cài package (người cài cần biết key này)
- `--wait 10` : Chờ tối đa 10 phút cho đến khi tạo xong

Khi thành công, bạn sẽ nhận được một **Subscriber Package Version Id** (bắt đầu bằng `04t`), ví dụ:

```
Successfully created the package version [04tXXXXXXXXXXXXXXX]
```

> **Lưu ý:** Quá trình tạo version có thể mất 5-15 phút tùy độ lớn của code.

---

## Bước 3: Cài Package vào Org đích

### 3.1 Authorize org đích

```bash
sf org login web --alias TargetOrg
```

### 3.2 Cài đặt package

```bash
sf package install --package 04tXXXXXXXXXXXXXXX --target-org TargetOrg --installation-key "FECCSM123" --wait 10
```

Thay `04tXXXXXXXXXXXXXXX` bằng Id bạn nhận được ở Bước 2.

---

## Bước 4: Kiểm tra kết quả

Xem danh sách package đã cài trong org:

```bash
sf package installed list --target-org TargetOrg
```

---

## Các lệnh hữu ích khác

| Lệnh | Mô tả |
|-------|--------|
| `sf package version list` | Xem tất cả version đã tạo |
| `sf package version promote --package 04tXXX` | Promote version thành Released (dùng cho production) |
| `sf package uninstall --package 04tXXX --target-org TargetOrg` | Gỡ package khỏi org |

---

## Quy trình tóm tắt

```
Code thay đổi → Tạo version mới (Bước 2) → Cài vào org đích (Bước 3) → Kiểm tra (Bước 4)
```

---

## Xử lý lỗi thường gặp

### "The Package Id isn't defined in sfdx-project.json"
→ Chưa có `packageAliases` trong `sfdx-project.json`. Chạy `sf package create` trước.

### "must include one, and only one, default package directory"
→ Đảm bảo có `"default": true` trong `packageDirectories`.

### "Installation key is incorrect"
→ Sai mật khẩu khi cài. Dùng đúng key đã set lúc tạo version.

---

## File cấu hình quan trọng

- `sfdx-project.json` : Khai báo package, path, version
- `force-app/` : Thư mục chứa toàn bộ metadata/code cần deploy
