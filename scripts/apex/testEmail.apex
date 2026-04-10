// Test direct de l'envoi d'email (bienvenue candidat + notification admin)
// Exécute les deux types d'email directement pour vérifier que Messaging.sendEmail fonctionne

String testEmail = 'meriem.rebhi.d6f3e18c6a1f@agentforce.com'; // email de test
String testFirstName = 'Test';
String testLastName = 'Email';
String testUsername = testEmail + '.test';

System.debug('=== TEST EMAIL BIENVENUE ===');
try {
    Messaging.SingleEmailMessage welcome = new Messaging.SingleEmailMessage();
    welcome.setToAddresses(new List<String>{ testEmail });
    welcome.setSubject('[TEST] Bienvenue sur le Portail RH Talan — Vos identifiants');
    welcome.setHtmlBody(
        '<div style="font-family:Segoe UI,Arial;max-width:600px;margin:auto;padding:30px;">'
        + '<h2 style="color:#2F7D59;">✅ Test Email Bienvenue</h2>'
        + '<p>Bonjour <strong>Test</strong>,</p>'
        + '<p>Votre candidature a été analysée et validée par notre IA.</p>'
        + '<div style="background:#f5f9f7;padding:20px;border-radius:10px;border-left:4px solid #2F7D59;margin:20px 0;">'
        + '<p><strong>Email :</strong> ' + testEmail + '</p>'
        + '<p><strong>Mot de passe temporaire :</strong> <code>Test@1234</code></p>'
        + '</div>'
        + '<p style="background:#fff8e1;border-left:4px solid #f59e0b;padding:12px;border-radius:6px;">⚠️ Ceci est un email de test — HR Talent Portal Talan</p>'
        + '</div>'
    );
    welcome.setSaveAsActivity(false);
    List<Messaging.SendEmailResult> welcomeResults = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ welcome });
    Boolean welcomeOk = welcomeResults[0].isSuccess();
    System.debug('Email bienvenue envoyé: ' + welcomeOk);
    if (!welcomeOk) {
        for(Messaging.SendEmailError err : welcomeResults[0].getErrors()) {
            System.debug('ERREUR bienvenue: ' + err.getMessage() + ' | Code: ' + err.getStatusCode());
        }
    }
} catch(Exception e) {
    System.debug('EXCEPTION email bienvenue: ' + e.getMessage());
}

System.debug('=== TEST EMAIL ADMIN (NOTIFICATION CONVERSION) ===');
try {
    String adminEmail = 'meriem.rebhi.d6f3e18c6a1f@agentforce.com';
    Messaging.SingleEmailMessage admin = new Messaging.SingleEmailMessage();
    admin.setToAddresses(new List<String>{ adminEmail });
    admin.setSubject('[TEST] ✅ Candidat converti : Test Email | Score IA : 75 %');
    admin.setHtmlBody(
        '<div style="font-family:Segoe UI,Arial;max-width:640px;margin:auto;padding:30px;">'
        + '<h2 style="color:#0f172a;">✅ Test Notification Admin</h2>'
        + '<p>Un candidat vient d\'être converti automatiquement.</p>'
        + '<div style="text-align:center;margin:20px 0;">'
        + '<span style="background:#2F7D59;color:#fff;font-size:24px;font-weight:900;padding:12px 32px;border-radius:50px;">★ 75 % IA</span>'
        + '</div>'
        + '<table style="width:100%;border-collapse:collapse;">'
        + '<tr><td style="padding:8px;color:#555;width:140px;">Nom</td><td style="padding:8px;font-weight:600;">Test Email</td></tr>'
        + '<tr><td style="padding:8px;color:#555;">Email</td><td style="padding:8px;">' + testEmail + '</td></tr>'
        + '<tr><td style="padding:8px;color:#555;">Score IA</td><td style="padding:8px;color:#2F7D59;font-weight:700;">75 %</td></tr>'
        + '</table>'
        + '<p style="color:#94a3b8;font-size:12px;margin-top:20px;">Ceci est un email de TEST — HR Talent Portal Talan Tunisie</p>'
        + '</div>'
    );
    admin.setSaveAsActivity(false);
    List<Messaging.SendEmailResult> adminResults = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ admin });
    Boolean adminOk = adminResults[0].isSuccess();
    System.debug('Email admin envoyé: ' + adminOk);
    if (!adminOk) {
        for(Messaging.SendEmailError err : adminResults[0].getErrors()) {
            System.debug('ERREUR admin: ' + err.getMessage() + ' | Code: ' + err.getStatusCode());
        }
    }
} catch(Exception e) {
    System.debug('EXCEPTION email admin: ' + e.getMessage());
}

// Vérifier les limites d'email utilisées
System.debug('=== LIMITES EMAIL ===');
System.debug('Email invocations utilisées: ' + Limits.getEmailInvocations() + ' / ' + Limits.getLimitEmailInvocations());

System.debug('=== FIN TEST EMAIL ===');
