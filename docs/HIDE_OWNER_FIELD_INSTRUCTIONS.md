# Hướng dẫn ẩn trường Case Owner cho COF/GSR Cases

## Vấn đề

- Salesforce không cho phép set `OwnerId = null`
- Khi có assignment (COF/GSR), trường Owner vẫn hiển thị nhưng không còn ý nghĩa
- Cần ẩn trường Owner trên giao diện

## Giải pháp

### Cách 1: Ẩn trong Page Layout (Khuyến nghị)

1. **Setup → Object Manager → Case**
2. **Page Layouts → Customer Case Layout** (hoặc Internal Case Layout)
3. Tìm field **Owner** trong layout
4. Kéo field **Owner** ra khỏi layout (hoặc move vào section ẩn)
5. **Save** layout

### Cách 2: Sử dụng Field-Level Security

1. **Setup → Object Manager → Case → Fields & Relationships**
2. Click vào field **Owner ID**
3. **Set Field-Level Security**
4. Bỏ check **Visible** cho các profiles cần ẩn
5. **Save**

### Cách 3: Sử dụng Dynamic Forms (Lightning Record Page)

1. **Setup → Lightning App Builder**
2. Mở **FEC_Customer_Case_Record_Page** hoặc **FEC_Internal_Case_Record_Page**
3. Tìm component hiển thị field Owner
4. Thêm **Visibility Rule**:
   - Field: `FEC_Assignment_Users__c`
   - Operator: `Is Blank`
   - Value: (empty)

   → Chỉ hiển thị Owner khi KHÔNG có assignment

5. **Save** và **Activate**

### Cách 4: Sử dụng CSS (Đã tạo sẵn)

File CSS đã được tạo: `FEC_HideOwnerForAssignment.css`

**Cách áp dụng:**

1. Deploy static resource
2. Thêm vào Lightning Record Page:
   ```xml
   <componentInstance>
       <componentName>forceCommunity:slds</componentName>
       <componentInstanceProperties>
           <name>stylesheetUrl</name>
           <value>{!$Resource.FEC_HideOwnerForAssignment}</value>
       </componentInstanceProperties>
   </componentInstance>
   ```

## Khuyến nghị

**Sử dụng Cách 1 (Page Layout)** vì:

- Đơn giản nhất
- Không cần code
- Dễ maintain
- Không ảnh hưởng performance

## Lưu ý

- Trường `FEC_Assignment_Users__c` được sử dụng để track assignments thay vì OwnerId
- Logic nghiệp vụ cần check `FEC_Assignment_Users__c` có giá trị thay vì check `OwnerId = null`
- Owner vẫn tồn tại trong database, chỉ ẩn trên UI

## Files liên quan

- `force-app/main/default/staticresources/FEC_HideOwnerForAssignment.css`
- `force-app/main/default/flexipages/FEC_Customer_Case_Record_Page.flexipage-meta.xml`
- `force-app/main/default/flexipages/FEC_Internal_Case_Record_Page.flexipage-meta.xml`
