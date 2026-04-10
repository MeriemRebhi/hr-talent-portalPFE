// TEST: Générer un token sécurisé et envoyer l'email de bienvenue avec le lien
String testEmail = 'm.rebhi24292@pi.tn';

// Trouver l'utilisateur portail
User u = [
    SELECT Id, Email, FirstName, LastName 
    FROM User 
    WHERE Email = :testEmail AND IsActive = true 
    LIMIT 1
];
System.debug('User trouvé: ' + u.FirstName + ' ' + u.LastName + ' (Id: ' + u.Id + ')');

// 1. Générer le token sécurisé
String token = PasswordResetController.generateResetToken(u.Id, u.Email);
System.debug('Token brut généré (64 hex chars): ' + token);
System.debug('Longueur du token: ' + token.length());

// 2. Construire l'URL
String resetUrl = PasswordResetController.buildResetUrl(token);
System.debug('URL de réinitialisation: ' + resetUrl);

// 3. Vérifier que le token est bien stocké hashé
List<Password_Reset_Token__c> stored = [
    SELECT Id, Token_Hash__c, Email__c, Expiration__c, Attempts__c, Is_Used__c, User__c
    FROM Password_Reset_Token__c
    WHERE User__c = :u.Id
    ORDER BY CreatedDate DESC LIMIT 1
];
if (!stored.isEmpty()) {
    System.debug('Token stocké (hash SHA-256): ' + stored[0].Token_Hash__c);
    System.debug('Expiration: ' + stored[0].Expiration__c);
    System.debug('Is_Used: ' + stored[0].Is_Used__c);
    System.debug('Attempts: ' + stored[0].Attempts__c);
}

// 4. Vérifier le token via validateToken
Map<String, String> validation = PasswordResetController.validateToken(token);
System.debug('Validation result: ' + validation);

// 5. Envoyer l'email de bienvenue avec le lien sécurisé
String html =
    '<div style="font-family:Segoe UI,Arial,sans-serif;max-width:600px;margin:auto;">'
    + '<div style="background:linear-gradient(135deg,#2F7D59,#1a4d2e);padding:30px;text-align:center;border-radius:12px 12px 0 0;">'
    + '<h1 style="color:#fff;margin:0;font-size:24px;">Portail RH Talan</h1>'
    + '<p style="color:rgba(255,255,255,.8);margin:8px 0 0;font-size:14px;">Votre espace candidat</p>'
    + '</div>'
    + '<div style="background:#fff;padding:30px;border:1px solid #e0e0e0;border-radius:0 0 12px 12px;">'
    + '<p style="font-size:16px;">Bonjour <strong>' + u.FirstName + '</strong>,</p>'
    + '<p>Ceci est un <strong>test</strong> du système sécurisé de définition de mot de passe.</p>'
    + '<p style="font-size:14px;color:#444;">Cliquez sur le bouton ci-dessous pour définir votre mot de passe :</p>'
    + '<p style="text-align:center;margin:30px 0;">'
    + '<a href="' + resetUrl + '" style="background:#2F7D59;color:#fff;padding:16px 48px;border-radius:8px;text-decoration:none;font-weight:bold;font-size:16px;display:inline-block;">Définir mon mot de passe &#8594;</a>'
    + '</p>'
    + '<div style="background:#f5f9f7;padding:16px 20px;border-radius:8px;border-left:4px solid #2F7D59;margin:20px 0;">'
    + '<p style="margin:0;font-size:13px;color:#334155;"><strong>&#128274; Sécurité :</strong></p>'
    + '<ul style="margin:8px 0 0;padding-left:20px;font-size:13px;color:#475569;">'
    + '<li>Ce lien est <strong>à usage unique</strong> et expire dans <strong>24 heures</strong></li>'
    + '<li>Token hashé SHA-256 (jamais stocké en clair)</li>'
    + '<li>Rate limiting : max 3 tentatives</li>'
    + '</ul></div>'
    + '<p style="color:#999;font-size:12px;text-align:center;border-top:1px solid #eee;padding-top:15px;">'
    + 'TEST — Système de réinitialisation sécurisée.</p>'
    + '</div></div>';

Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
mail.setToAddresses(new List<String>{ testEmail });
mail.setSubject('[TEST] Portail RH Talan — Définissez votre mot de passe');
mail.setHtmlBody(html);
mail.setSaveAsActivity(false);
Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
System.debug('✅ Email de test envoyé à: ' + testEmail);
System.debug('✅ URL dans l\'email: ' + resetUrl);

// 6. Vérifier l'audit log
List<Security_Audit_Log__c> logs = [
    SELECT Action__c, Email__c, Severity__c, Details__c, Timestamp__c
    FROM Security_Audit_Log__c
    ORDER BY Timestamp__c DESC LIMIT 5
];
System.debug('=== AUDIT LOG ===');
for (Security_Audit_Log__c log : logs) {
    System.debug(log.Timestamp__c + ' | ' + log.Severity__c + ' | ' + log.Action__c + ' | ' + log.Email__c + ' | ' + log.Details__c);
}
