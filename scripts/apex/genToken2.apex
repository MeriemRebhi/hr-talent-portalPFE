List<User> users = [SELECT Id, Email FROM User WHERE Email = 'm.rebhi24292@pi.tn' AND IsActive = true LIMIT 1];
if (users.isEmpty()) {
    users = [SELECT Id, Email FROM User WHERE IsActive = true LIMIT 1];
}
User u = users[0];
String rawToken = String.valueOf(Crypto.getRandomInteger()) + String.valueOf(Crypto.getRandomInteger()) + String.valueOf(Crypto.getRandomInteger());
Blob hashBlob = Crypto.generateDigest('SHA-256', Blob.valueOf(rawToken));
String tokenHash = EncodingUtil.convertToHex(hashBlob);
Password_Reset_Token__c prt = new Password_Reset_Token__c(
    Token_Hash__c = tokenHash,
    User__c = u.Id,
    Email__c = u.Email,
    Expiration__c = Datetime.now().addHours(24),
    Is_Used__c = false,
    Attempts__c = 0
);
insert prt;
System.debug('TOKEN=' + rawToken);
System.debug('EMAIL=' + u.Email);
