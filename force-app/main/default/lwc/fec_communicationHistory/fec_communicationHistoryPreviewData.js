import { STR_EMPTY } from 'c/fec_CommonConst';

const TYPES = ['SMS', 'Email', 'Voice'];
const TEMPLATES = ['PAYMENT_REMINDER_V2', 'LEGAL_NOTICE_STD', 'CALL_OUTBOUND'];

function pad(n) {
    return String(n).padStart(2, '0');
}

/** 60 dòng mẫu — test phân trang / sort (Preview App Builder). */
function buildPreviewCommunicationHistory() {
    const rows = [];
    const start = new Date(2026, 3, 28, 18, 0, 0); // 28/04/2026 18:00:00

    for (let i = 0; i < 60; i++) {
        const dt = new Date(start);
        dt.setMinutes(start.getMinutes() - i * 23);

        const dd = pad(dt.getDate());
        const mm = pad(dt.getMonth() + 1);
        const yyyy = dt.getFullYear();
        const HH = pad(dt.getHours());
        const MM = pad(dt.getMinutes());
        const SS = pad(dt.getSeconds());

        rows.push({
            ContractNumber: `HD-2024-${String(100000 + i).slice(-6)}`,
            CommunicationType: TYPES[i % TYPES.length],
            Template: `${TEMPLATES[i % TEMPLATES.length]} #${i + 1}`,
            CampaignName: `Campaign preview — nhóm ${1 + Math.floor(i / 15)}`,
            PhoneNumber: i % 7 === 0 ? STR_EMPTY : `090${String(1000000 + i * 113).slice(-7)}`,
            CommunicatedDate: `${dd}/${mm}/${yyyy} ${HH}:${MM}:${SS}`,
            Address2: `${i + 1} Đường Mẫu, Q.${(i % 12) + 1}, TP.HCM`
        });
    }
    return rows;
}

export const PREVIEW_COMMUNICATION_HISTORY = buildPreviewCommunicationHistory();
