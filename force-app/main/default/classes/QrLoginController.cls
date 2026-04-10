public without sharing class QrLoginController {

    @AuraEnabled
    public static String loginWithCredentials(String username, String password) {
        try {
            String startUrl = '/s/dashboard';

            // Si l'utilisateur saisit son email (contient @), on cherche le vrai username Salesforce
            String sfUsername = username;
            if (username != null && username.contains('@')) {
                List<User> users = [
                    SELECT Username FROM User
                    WHERE Email = :username
                    AND IsActive = true
                    AND UserType IN ('CspLitePortal','CustomerPortal','PowerCustomerSuccess','PowerPartner')
                    LIMIT 1
                ];
                if (!users.isEmpty()) {
                    sfUsername = users[0].Username;
                }
            }

            ApexPages.PageReference pageRef = Site.login(sfUsername, password, startUrl);
            if (pageRef != null) {
                return pageRef.getUrl();
            }
            throw new AuraHandledException('Email ou mot de passe incorrect.');
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Email ou mot de passe incorrect.');
        }
    }

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
