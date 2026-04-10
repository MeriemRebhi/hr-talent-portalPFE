// Réactiver le user portail et renvoyer le welcome email
// User: m.rebhi24292@pi.tn.1774474869164 | Contact: 003fj00000kLM6HAAW

List<User> users = [
    SELECT Id, Username, Email, IsActive, ContactId, FirstName, LastName
    FROM User
    WHERE Email = 'm.rebhi24292@pi.tn'
    AND UserType IN ('CspLitePortal','CustomerPortal','PowerCustomerSuccess','PowerPartner')
    LIMIT 1
];

if (users.isEmpty()) {
    System.debug('❌ User portail non trouvé');
} else {
    User u = users[0];
    System.debug('📋 User trouvé: ' + u.Username + ' | Active: ' + u.IsActive);
    
    // 1. Réactiver si inactif
    if (!u.IsActive) {
        u.IsActive = true;
        update u;
        System.debug('✅ User réactivé');
    }
    
    // 2. Définir un nouveau mot de passe
    String tempPwd = 'Talan2026!Hr';
    System.setPassword(u.Id, tempPwd);
    System.debug('✅ Mot de passe défini: ' + tempPwd);
    
    // 3. Envoyer l'email de bienvenue
    String siteUrl = 'https://orgfarm-3ed211f8bb-dev-ed.develop.my.site.com/home2/s/loginp';
    String html =
        '<div style="font-family:Segoe UI,Arial,sans-serif;max-width:600px;margin:auto;">'
        + '<div style="background:linear-gradient(135deg,#2F7D59,#1a4d2e);padding:30px;text-align:center;border-radius:12px 12px 0 0;">'
        + '<h1 style="color:#fff;margin:0;font-size:24px;">Portail RH Talan</h1>'
        + '<p style="color:rgba(255,255,255,.8);margin:8px 0 0;font-size:14px;">Votre espace candidat</p>'
        + '</div>'
        + '<div style="background:#fff;padding:30px;border:1px solid #e0e0e0;border-radius:0 0 12px 12px;">'
        + '<p style="font-size:16px;">Bonjour <strong>' + (u.FirstName != null ? u.FirstName : '') + '</strong>,</p>'
        + '<p>Votre candidature a été <strong style="color:#2F7D59;">analysée et validée</strong>.</p>'
        + '<div style="background:#f5f9f7;padding:20px;border-radius:10px;border-left:4px solid #2F7D59;margin:20px 0;">'
        + '<table style="width:100%;border-collapse:collapse;">'
        + '<tr><td style="color:#666;width:140px;padding:8px 4px;">Email :</td>'
        + '<td style="font-weight:bold;padding:8px 4px;">' + u.Email + '</td></tr>'
        + '<tr><td style="color:#666;padding:8px 4px;">Mot de passe :</td>'
        + '<td style="font-weight:bold;padding:8px 4px;font-family:monospace;font-size:15px;">' + tempPwd + '</td></tr>'
        + '</table></div>'
        + '<p style="text-align:center;margin:25px 0;">'
        + '<a href="' + siteUrl + '" style="background:#2F7D59;color:#fff;padding:14px 40px;border-radius:8px;text-decoration:none;font-weight:bold;">Se connecter au Portail</a>'
        + '</p>'
        + '</div></div>';
    
    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
    mail.setToAddresses(new List<String>{ u.Email });
    mail.setSubject('Bienvenue sur le Portail RH Talan — Vos identifiants de connexion');
    mail.setHtmlBody(html);
    mail.setSaveAsActivity(false);
    Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
    System.debug('✅ Email de bienvenue envoyé à: ' + u.Email);
}
