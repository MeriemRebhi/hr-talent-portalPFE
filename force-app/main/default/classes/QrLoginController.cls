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

    /**
     * Génère un jeton QR unique via CSPRNG (fonctionne pour les Guest Users).
     * Retourne le token en clair pour l'encodage dans le QR code.
     */
    @AuraEnabled(cacheable=false)
    public static String generateQrToken() {
        // Utiliser Crypto.getRandomInteger() (CSPRNG) au lieu de UserInfo.getSessionId()
        // car getSessionId() retourne null pour les Guest Users
        Integer rand1 = Crypto.getRandomInteger();
        Integer rand2 = Crypto.getRandomInteger();
        Integer rand3 = Crypto.getRandomInteger();
        String rawSeed = String.valueOf(rand1) + String.valueOf(rand2) + String.valueOf(rand3)
                       + String.valueOf(Datetime.now().getTime());
        String token = EncodingUtil.convertToHex(
            Crypto.generateDigest('SHA-256', Blob.valueOf(rawSeed))
        );

        QrLogin__c qr = new QrLogin__c(
            Token__c = token,
            Is_Validated__c = false,
            Expiration__c = Datetime.now().addMinutes(5)
        );
        insert qr;
        return token;
    }

    /**
     * Vérifie si le jeton QR a été validé par le mobile (polling desktop).
     */
    @AuraEnabled(cacheable=false)
    public static Boolean checkQrTokenValidated(String token) {
        List<QrLogin__c> qrList = [
            SELECT Is_Validated__c
            FROM QrLogin__c
            WHERE Token__c = :token
            AND Expiration__c > :Datetime.now()
            LIMIT 1
        ];
        return !qrList.isEmpty() && qrList[0].Is_Validated__c;
    }

    /**
     * Valide le jeton QR côté mobile (appelé par l'utilisateur authentifié).
     * Marque Is_Validated__c = true pour que le desktop détecte la validation.
     */
    @AuraEnabled(cacheable=false)
    public static Boolean validateQrToken(String token) {
        List<QrLogin__c> qrList = [
            SELECT Id
            FROM QrLogin__c
            WHERE Token__c = :token
            AND Expiration__c > :Datetime.now()
            AND Is_Validated__c = false
            LIMIT 1
        ];
        if (!qrList.isEmpty()) {
            qrList[0].Is_Validated__c = true;
            update qrList;
            return true;
        }
        return false;
    }

    /**
     * Nettoyage : supprime les tokens QR expirés (appelé périodiquement ou à la demande).
     */
    @AuraEnabled(cacheable=false)
    public static void cleanupExpiredTokens() {
        List<QrLogin__c> expired = [
            SELECT Id FROM QrLogin__c
            WHERE Expiration__c < :Datetime.now()
            LIMIT 200
        ];
        if (!expired.isEmpty()) {
            delete expired;
        }
    }
}
