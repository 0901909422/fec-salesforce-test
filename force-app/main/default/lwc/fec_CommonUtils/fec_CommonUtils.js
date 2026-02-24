const formatDate = (curr) => {
  if (!curr) {
    return null;
  }

  curr = new Date(curr);
  const year = curr.getFullYear();
  const month = String(curr.getMonth() + 1).padStart(2, "0"); // Months are zero-indexed
  const day = String(curr.getDate()).padStart(2, "0");

  return `${day}-${month}-${year}`;
};

const mask = (s, keep = 4) => {
  const len = s.length;

  if (len <= 2) return "*".repeat(len);

  // Shrink keep until it fits
  while (keep * 2 >= len && keep > 1) {
    keep--;
  }

  return s.slice(0, keep) + "***" + s.slice(-keep);
};

const formatDateVNI = (d) => {
  if (!d) return '';
  const date = new Date(d);
  return `${date.getDate().toString().padStart(2, '0')}/${(date.getMonth() + 1).toString().padStart(2, '0')}/${date.getFullYear()}`;
}

const maskWorkPhone = (phone) => {
    if (phone.length < 7) {
        return phone;
    }

    let first = phone.substring(0, 4);
    let last  = phone.substring(phone.length - 3);

    return first + '***' + last;
}

const maskValue = (value, showFull) => {
  if (!value) return '';
  if (showFull) return value;

  const v = value.trim();

  /* =====================
  * PASSPORT ID (bắt đầu bằng chữ)
  * Hiển thị: 2 ký tự đầu + 3 ký tự cuối
  * ===================== */
  if (/^[A-Za-z]/.test(v)) {
    if (v.length <= 5) return v;
    return (
      v.substring(0, 2) +
      '*'.repeat(v.length - 5) +
      v.slice(-3)
    );
  }

  /* =====================
        * PHONE NUMBER: 84xxxxxxxxx
        * Hiển thị: 5 số đầu + 3 số cuối
        * Ví dụ: 84901***678
        * ===================== */
        if (/^84\d{9}$/.test(v)) {
            return (
                v.substring(0, 5) +
                '*'.repeat(v.length - 8) +
                v.slice(-3)
            );
        }

  /* =====================
  * PHONE NUMBER (10 số)
  * Hiển thị: 4 số đầu + 3 số cuối
  * Ví dụ: 0906***678
  * ===================== */
  if (/^\d{10}$/.test(v)) {
    return (
      v.substring(0, 4) +
      '*'.repeat(v.length - 7) +
      v.slice(-3)
    );
  }

  /* =====================
  * CCCD (toàn số, > 6)
  * Hiển thị: 3 số đầu + 3 số cuối
  * ===================== */
  if (/^\d+$/.test(v)) {
    if (v.length <= 6) return v;
    return (
      v.substring(0, 3) +
      '*'.repeat(v.length - 6) +
      v.slice(-3)
    );
  }

  return v;
}

export { formatDate, mask, formatDateVNI, maskWorkPhone, maskValue };
