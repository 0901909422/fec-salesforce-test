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

export { formatDate, mask };