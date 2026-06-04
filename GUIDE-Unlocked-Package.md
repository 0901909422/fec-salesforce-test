# Hướng Dẫn Salesforce Unlocked Package — Từ A đến Z

> Package: **GitLabPipelinesPkg**  
> Package ID: `0HoIW000000021p0AA`  
> Installation Key: `Fec@123`  
> Source Path: `force-app`

---

## Mục Lục

1. [Yêu cầu trước khi bắt đầu](#1-yêu-cầu-trước-khi-bắt-đầu)
2. [Cấu trúc project](#2-cấu-trúc-project)
3. [Tạo Package Version](#3-tạo-package-version)
4. [Cài đặt Package vào Org](#4-cài-đặt-package-vào-org)
5. [Promote Version (cho Production)](#5-promote-version-cho-production)
6. [Deploy lên Production](#6-deploy-lên-production)
7. [Quy trình CI/CD với GitLab](#7-quy-trình-cicd-với-gitlab)
8. [Troubleshooting](#8-troubleshooting)
9. [Rollback khi deploy bị lỗi](#9-rollback-khi-deploy-bị-lỗi)

---

## 1. Yêu cầu trước khi bắt đầu

### Cài đặt

| Tool | Cách cài | Kiểm tra |
|------|----------|----------|
| Salesforce CLI (sf) | `npm install -g @salesforce/cli` | `sf --version` |
| Git | https://git-scm.com | `git --version` |
| VS Code + SF Extensions | Marketplace → "Salesforce Extension Pack" | — |

### Org cần có

| Org | Mục đích | Cách lấy |
|-----|----------|----------|
| Dev Hub | Tạo package & version | Org Production hoặc Partner Dev Hub, enable Dev Hub trong Setup |
| Sandbox / Scratch Org | Test cài package | Tạo từ Dev Hub hoặc dùng Sandbox |
| Production | Deploy bản chính thức | Org chính của khách hàng |

### Authorize Org (bắt buộc)

```bash
# Login vào Dev Hub (alias: prod)
sf org login web --alias prod --set-default-dev-hub

# Login vào Sandbox (để test install)
sf org login web --alias MySandbox

# Login vào Production (khi deploy)
sf org login web --alias prod --instance-url https://login.salesforce.com
```

> 💡 Sau khi login, kiểm tra: `sf org list` để thấy các org đã connect.

---

## 2. Cấu trúc Project

File `sfdx-project.json` hiện tại:

```json
{
  "packageDirectories": [
    {
      "versionName": "ver 0.1",
      "versionNumber": "0.1.0.NEXT",
      "path": "force-app",
      "default": false,
      "package": "GitLabPipelinesPkg",
      "versionDescription": ""
    }
  ],
  "namespace": "",
  "sfdcLoginUrl": "https://login.salesforce.com",
  "sourceApiVersion": "65.0",
  "packageAliases": {
    "GitLabPipelinesPkg": "0HoIW000000021p0AA"
  }
}
```

**Giải thích:**

| Field | Ý nghĩa |
|-------|---------|
| `path: "force-app"` | Thư mục chứa source code của package |
| `package` | Tên package (đã tạo sẵn) |
| `versionNumber: "0.1.0.NEXT"` | NEXT = tự động tăng build number |
| `packageAliases` | Map tên → Package ID |
| `namespace: ""` | No-namespace package (không lock metadata) |

### Thư mục source code

```
force-app/
└── main/
    └── default/
        ├── classes/          ← Apex classes
        ├── triggers/         ← Apex triggers
        ├── lwc/              ← Lightning Web Components
        ├── aura/             ← Aura components
        ├── objects/          ← Custom Objects & Fields
        ├── layouts/          ← Page Layouts
        ├── flows/            ← Flows
        ├── permissionsets/   ← Permission Sets
        └── ...
```

---

## 3. Tạo Package Version

### Bước 3.1: Đảm bảo code sẵn sàng

```bash
# Kiểm tra source format hợp lệ
sf project deploy preview --target-org MySandbox
```

### Bước 3.2: Tạo version mới

```bash
sf package version create \
  --package "GitLabPipelinesPkg" \
  --installation-key "Fec@123" \
  --wait 20 \
  --target-dev-hub prod \
  --code-coverage
```

**Giải thích tham số:**

| Tham số | Ý nghĩa |
|---------|---------|
| `--package` | Tên package (hoặc dùng ID: 0HoIW000000021p0AA) |
| `--installation-key` | Mật khẩu bảo vệ package (người install cần nhập) |
| `--wait 20` | Chờ tối đa 20 phút |
| `--code-coverage` | Chạy test, yêu cầu ≥75% coverage |
| `--target-dev-hub` | Alias của Dev Hub org |

### Bước 3.3: Xem kết quả

Khi thành công, bạn nhận được **Subscriber Package Version ID** (bắt đầu bằng `04t`):

```
Successfully created the package version [08cXXXXXXXXXXXXX]
Subscriber Package Version Id: 04tXXXXXXXXXXXXXXX
```

> ⚠️ Ghi lại ID `04t...` — đây là ID dùng để install.

### Bước 3.4: Kiểm tra trạng thái version

```bash
sf package version list \
  --packages "GitLabPipelinesPkg" \
  --target-dev-hub prod
```

---

## 4. Cài đặt Package vào Org

### Bước 4.1: Install vào Sandbox (test trước)

```bash
sf package install \
  --package 04tXXXXXXXXXXXXXXX \
  --target-org MySandbox \
  --installation-key "Fec@123" \
  --wait 15 \
  --publish-wait 10
```

| Tham số | Ý nghĩa |
|---------|---------|
| `--package` | Subscriber Version ID (04t...) |
| `--target-org` | Org muốn cài vào |
| `--installation-key` | Password đã set khi tạo version |
| `--publish-wait` | Chờ package sẵn sàng (version mới cần vài phút) |

### Bước 4.2: Verify sau khi install

```bash
sf package installed list --target-org MySandbox
```

### Bước 4.3: Test trong Sandbox

- Mở Sandbox, kiểm tra các component đã có
- Chạy test Apex: Setup → Apex Test Execution
- Kiểm tra Permission Sets đã deploy

---

## 5. Promote Version (cho Production)

> ⚠️ **BẮT BUỘC** promote trước khi install vào Production.  
> Version chưa promote = "beta", không install được vào Production.

```bash
sf package version promote \
  --package 04tXXXXXXXXXXXXXXX \
  --target-dev-hub prod
```

Sau khi promote:
- Version trở thành **released** (không thể xóa)
- Có thể install vào Production org

---

## 6. Deploy lên Production

### Bước 6.1: Install vào Production

```bash
sf package install \
  --package 04tXXXXXXXXXXXXXXX \
  --target-org prod \
  --installation-key "Fec@123" \
  --wait 15 \
  --publish-wait 10 \
  --security-type AdminsOnly
```

| Tham số bổ sung | Ý nghĩa |
|----------------|---------|
| `--security-type` | `AdminsOnly` (chỉ admin access) hoặc `AllUsers` |

### Bước 6.2: Post-install tasks

1. **Assign Permission Sets** cho users:
   ```bash
   sf org assign permset --name YourPermSetName --target-org prod
   ```

2. **Deploy metadata không nằm trong package** (nếu có):
   - Profiles, Roles, Page Layouts assignments
   - Custom Settings data
   - Named Credentials

---

## 7. Quy trình CI/CD với GitLab

### Workflow tổng quan

```
Developer push code
       ↓
GitLab Pipeline trigger
       ↓
┌─────────────────────┐
│ 1. Validate source  │
│ 2. Create version   │
│ 3. Install Sandbox  │
│ 4. Run tests        │
│ 5. Promote (manual) │
│ 6. Install Prod     │
└─────────────────────┘
```

### Ví dụ `.gitlab-ci.yml` cơ bản

```yaml
stages:
  - validate
  - package
  - test
  - promote
  - deploy

variables:
  PACKAGE_NAME: "GitLabPipelinesPkg"
  INSTALL_KEY: "Fec@123"

validate:
  stage: validate
  script:
    - sf org login sfdx-url --sfdx-url-file devhub-auth.txt --alias DevHub --set-default-dev-hub
    - sf project deploy preview --target-org DevHub

create_version:
  stage: package
  script:
    - sf org login sfdx-url --sfdx-url-file devhub-auth.txt --alias DevHub --set-default-dev-hub
    - |
      VERSION_OUTPUT=$(sf package version create \
        --package "$PACKAGE_NAME" \
        --installation-key "$INSTALL_KEY" \
        --wait 20 \
        --target-dev-hub DevHub \
        --code-coverage \
        --json)
    - echo "$VERSION_OUTPUT"
    - SUBSCRIBER_ID=$(echo $VERSION_OUTPUT | jq -r '.result.SubscriberPackageVersionId')
    - echo "SUBSCRIBER_ID=$SUBSCRIBER_ID" >> version.env
  artifacts:
    reports:
      dotenv: version.env

install_sandbox:
  stage: test
  script:
    - sf org login sfdx-url --sfdx-url-file sandbox-auth.txt --alias Sandbox
    - |
      sf package install \
        --package "$SUBSCRIBER_ID" \
        --target-org Sandbox \
        --installation-key "$INSTALL_KEY" \
        --wait 15 \
        --publish-wait 10
    - sf apex run test --target-org Sandbox --wait 10

promote:
  stage: promote
  when: manual
  script:
    - sf org login sfdx-url --sfdx-url-file devhub-auth.txt --alias DevHub --set-default-dev-hub
    - sf package version promote --package "$SUBSCRIBER_ID" --target-dev-hub DevHub

deploy_prod:
  stage: deploy
  when: manual
  script:
    - sf org login sfdx-url --sfdx-url-file prod-auth.txt --alias Prod
    - |
      sf package install \
        --package "$SUBSCRIBER_ID" \
        --target-org Prod \
        --installation-key "$INSTALL_KEY" \
        --wait 15 \
        --security-type AdminsOnly
```

### Tạo SFDX Auth URL file

```bash
# Lấy auth URL của org
sf org display --target-org prod --verbose

# Copy dòng "Sfdx Auth Url" → lưu vào file
# Thêm file vào GitLab CI/CD Variables (type: File)
```

---

## 8. Troubleshooting

| Lỗi | Nguyên nhân | Cách fix |
|-----|-------------|----------|
| `Package version is not fully available` | Version mới tạo, chưa propagate | Thêm `--publish-wait 10` hoặc đợi 5-10 phút |
| `Code coverage must be at least 75%` | Test coverage < 75% | Viết thêm test classes |
| `Installation key is invalid` | Sai password | Kiểm tra lại key: `Fec@123` |
| `Cannot install beta version in production` | Chưa promote | Chạy `sf package version promote` |
| `Scratch org expired` | Scratch org hết hạn (30 ngày) | Tạo scratch org mới |
| `Package install failed: dependency` | Package phụ thuộc package khác | Install dependency trước |
| `INVALID_TYPE: Cannot create version` | Metadata type không hỗ trợ trong package | Tách metadata đó ra deploy riêng |

### Lệnh debug hữu ích

```bash
# Xem chi tiết version (bao gồm validation errors)
sf package version report --package 04tXXX --target-dev-hub prod --verbose

# Xem install status
sf package install report --request-id 0HfXXX --target-org MySandbox

# Xem tất cả versions
sf package version list --packages "GitLabPipelinesPkg" --target-dev-hub prod --verbose

# Xem packages trong org
sf package installed list --target-org MySandbox
```

---

## Tóm tắt quy trình nhanh

```
1. Code → push vào force-app/
2. sf package version create → lấy 04t ID
3. sf package install → test ở Sandbox
4. sf package version promote → unlock cho Production
5. sf package install → deploy Production
6. Assign Permission Sets → users dùng được
```

> 📌 Mỗi lần thay đổi code → tạo version mới → install/upgrade. Package version là immutable (không sửa được sau khi tạo).

---

## 9. Rollback khi deploy bị lỗi

### Cách 1: Install lại version cũ (khuyến nghị)

Unlocked Package hỗ trợ **upgrade/downgrade** bằng cách install version trước đó:

```bash
# Xem tất cả versions đã tạo
sf package version list --packages "GitLabPipelinesPkg" --target-dev-hub prod --verbose

# Install lại version cũ (04t... của version trước)
sf package install \
  --package 04tPREVIOUS_VERSION_ID \
  --target-org prod \
  --installation-key "Fec@123" \
  --wait 15
```

> 💡 Mỗi version mới install sẽ **ghi đè** version hiện tại. Không cần uninstall trước.

### Cách 2: Uninstall package (xóa hoàn toàn)

> ⚠️ **NGUY HIỂM** — sẽ xóa TẤT CẢ metadata và data liên quan đến package.

```bash
sf package uninstall \
  --package 04tXXXXXXXXXXXXXXX \
  --target-org prod \
  --wait 15
```

**Khi nào dùng:** Package gây lỗi nghiêm trọng, không downgrade được.  
**Rủi ro:** Mất data trong custom objects thuộc package, references bị broken, KHÔNG thể undo.

### Cách 3: Hotfix nhanh (tạo version mới)

```bash
# 1. Fix code trong force-app/
# 2. Tạo version mới
sf package version create \
  --package "GitLabPipelinesPkg" \
  --installation-key "Fec@123" \
  --wait 20 \
  --target-dev-hub prod \
  --code-coverage

# 3. Promote
sf package version promote --package 04tNEW_VERSION --target-dev-hub prod

# 4. Install version mới
sf package install \
  --package 04tNEW_VERSION \
  --target-org prod \
  --installation-key "Fec@123" \
  --wait 15
```

### Rollback checklist

| Bước | Action | Verify |
|------|--------|--------|
| 1 | Xác định version đang lỗi | `sf package installed list --target-org prod` |
| 2 | Tìm version stable trước đó | `sf package version list --packages "GitLabPipelinesPkg" --target-dev-hub prod` |
| 3 | Install version cũ | `sf package install --package 04tOLD...` |
| 4 | Kiểm tra | Mở org, test chức năng chính |
| 5 | Thông báo team | Slack/email — "đã rollback về vX.Y.Z" |

---

## Metadata KHÔNG hỗ trợ trong Unlocked Package

Những thứ cần deploy riêng (dùng `sf project deploy start`):

- **UserRole** — Role hierarchy
- **Profile** — chỉ hỗ trợ partial (field permissions, layout assignments)
- **Custom Settings data** — chỉ deploy definition, không data
- **Named Credentials** — chứa secrets, deploy riêng
- **Connected Apps** — org-specific config
- **Auth Providers** — org-specific
- **Remote Site Settings** — environment-specific URLs

### Cách deploy metadata ngoài package

```bash
# Tạo thư mục riêng cho unpackaged metadata
# Ví dụ: unpackaged/roles/, unpackaged/profiles/

sf project deploy start \
  --source-dir unpackaged/ \
  --target-org prod \
  --wait 10
```

