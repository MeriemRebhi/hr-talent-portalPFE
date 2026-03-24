public with sharing class QrLoginController {
    @AuraEnabled(cacheable=false)
    public static String generateQrToken() {
        String token = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(UserInfo.getSessionId() + Datetime.now().getTime())));
        QrLogin__c qr = new QrLogin__c(
            Token__c = token,
            Is_Validated__c = false,
            Expiration__c = Datetime.now().addMinutes(5)
        );
        insert qr;
        return token;
    }

    @AuraEnabled(cacheable=false)
    public static Boolean checkQrTokenValidated(String token) {
        List<QrLogin__c> qrList = [SELECT Is_Validated__c FROM QrLogin__c WHERE Token__c = :token AND Expiration__c > :Datetime.now() LIMIT 1];
        return !qrList.isEmpty() && qrList[0].Is_Validated__c;
    }

    @AuraEnabled(cacheable=false)
    public static Boolean validateQrToken(String token) {
        List<QrLogin__c> qrList = [SELECT Id FROM QrLogin__c WHERE Token__c = :token AND Expiration__c > :Datetime.now() LIMIT 1];
        if (!qrList.isEmpty()) {
            qrList[0].Is_Validated__c = true;
            update qrList;
            return true;
        }
        return false;
    }
}
