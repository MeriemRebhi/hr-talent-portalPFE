// Génère un token de reset pour prendre un screenshot de la page setPassword
// Cherche un utilisateur Community actif
List<User> users = [SELECT Id, Email FROM User WHERE IsActive = true AND UserType = 'CspLitePortal' LIMIT 1];

if (users.isEmpty()) {
    users = [SELECT Id, Email FROM User WHERE IsActive = true AND Email != null LIMIT 1];
}

User u = users[0];

// Générer un token aléatoire
String rawToken = String.valueOf(Crypto.getRandomInteger()) 
    + String.valueOf(Crypto.getRandomInteger()) 
    + String.valueOf(Crypto.getRandomInteger());

// Hash SHA-256
Blob hashBlob = Crypto.generateDigest('SHA-256', Blob.valueOf(rawToken));
String tokenHash = EncodingUtil.convertToHex(hashBlob);

// Créer le record
Password_Reset_Token__c prt = new Password_Reset_Token__c(
    Token_Hash__c = tokenHash,
    User__c = u.Id,
    Email__c = u.Email,
    Expiration__c = Datetime.now().addHours(24),
    Is_Used__c = false,
    Attempts__c = 0
);
insert prt;

System.debug('=== TOKEN BRUT (pour URL) : ' + rawToken);
System.debug('=== URL : /s/set-password?token=' + rawToken);
System.debug('=== User : ' + u.Email);
