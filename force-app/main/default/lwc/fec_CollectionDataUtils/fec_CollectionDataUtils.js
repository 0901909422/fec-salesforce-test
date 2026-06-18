import CONTRACT_FIELD from '@salesforce/schema/Case.FEC_Contract_Number__c';
import RT_NAME_FIELD from '@salesforce/schema/Case.RecordType.Name';
import PRODUCT_TYPE_NAME_FIELD from '@salesforce/schema/Case.FEC_Product_Type__r.Name';
import ACCOUNT_NUMBER_FIELD from '@salesforce/schema/Case.FEC_Account_Number__c';
import ACCT_OR_CONTRACT_ACCT_FIELD from '@salesforce/schema/Case.FEC_Account_or_Contract__r.FEC_Account_Number__c';

/** Khớp FEC_ConstantCommon.PRODUCT_TYPE_CARD_CASE */
const PRODUCT_TYPE_CARD_CASE = 'Card';

export const COLLECTION_CASE_FIELDS = [
    CONTRACT_FIELD,
    RT_NAME_FIELD,
    PRODUCT_TYPE_NAME_FIELD,
    ACCOUNT_NUMBER_FIELD,
    ACCT_OR_CONTRACT_ACCT_FIELD
];

/**
 * Đọc các field Case cần cho Collection History API.
 * @param {object} data - Kết quả getRecord wire
 */
export function parseCollectionCaseRecord(data) {
    if (!data?.fields) {
        return null;
    }
    return {
        contractNumber: data.fields.FEC_Contract_Number__c?.value,
        recordTypeName: data.fields.RecordType?.displayValue,
        productTypeName: data.fields.FEC_Product_Type__r?.displayValue,
        accountNumber: data.fields.FEC_Account_Number__c?.value,
        accountOrContractAccountNumber:
            data.fields.FEC_Account_or_Contract__r?.value?.fields?.FEC_Account_Number__c?.value
    };
}

/**
 * Card → accountNumber (bỏ số 0 đầu); Loan/khác → contractNumber.
 */
export function getCollectionApiContractNumber(caseInfo) {
    if (!caseInfo) {
        return null;
    }

    if (isCardProductType(caseInfo.productTypeName)) {
        const accountNumber =
            caseInfo.accountOrContractAccountNumber ||
            caseInfo.accountNumber ||
            caseInfo.contractNumber;
        return normalizeAccountNumberForApi(accountNumber);
    }

    return caseInfo.contractNumber;
}

/**
 * Account number: bỏ số 0 ở đầu trước khi gọi API (chỉ khi chuỗi toàn chữ số).
 * Dùng regex thay vì Number() để tránh mất precision với account 16–19 chữ số.
 */
function normalizeAccountNumberForApi(accountNumber) {
    if (accountNumber == null || accountNumber === '') {
        return accountNumber;
    }

    const trimmed = String(accountNumber).trim();
    if (!/^\d+$/.test(trimmed)) {
        return trimmed;
    }

    const normalized = trimmed.replace(/^0+/, '');
    return normalized === '' ? '0' : normalized;
}

function isCardProductType(productTypeName) {
    return (
        productTypeName &&
        String(productTypeName).trim().toLowerCase() === PRODUCT_TYPE_CARD_CASE.toLowerCase()
    );
}
