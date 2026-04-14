// Envoyer le même email de bienvenue que lors de la conversion Lead
List<User> users = [SELECT Id, Username, Email, ContactId, FirstName FROM User WHERE Email = 'roihizeineb123@gmail.com' AND IsActive = true LIMIT 1];
if (users.isEmpty()) {
    System.debug('ERROR: No active user found');
} else {
    User u = users[0];
    String firstName = u.FirstName != null ? u.FirstName : 'Candidat';
    
    // Générer un token sécurisé (même méthode que la conversion)
    String token = PasswordResetController.generateResetToken(u.Id, u.Email);
    String resetUrl = PasswordResetController.buildResetUrl(token);
    
    // Même template que sendWelcomeEmail de CVScoringService
    String html =
        '<div style="font-family:Segoe UI,Arial,sans-serif;max-width:600px;margin:auto;">'
        + '<div style="background:linear-gradient(135deg,#2F7D59,#1a4d2e);padding:30px;text-align:center;border-radius:12px 12px 0 0;">'
        + '<h1 style="color:#fff;margin:0;font-size:24px;">Portail RH Talan</h1>'
        + '<p style="color:rgba(255,255,255,.8);margin:8px 0 0;font-size:14px;">Votre espace candidat</p>'
        + '</div>'
        + '<div style="background:#fff;padding:30px;border:1px solid #e0e0e0;border-radius:0 0 12px 12px;">'
        + '<p style="font-size:16px;">Bonjour <strong>' + firstName + '</strong>,</p>'
        + '<p>Votre compte sur le Portail RH Talan a été <strong style="color:#2F7D59;">activé</strong> !</p>'
        + '<p style="font-size:14px;color:#444;">Pour accéder à votre espace candidat, veuillez définir votre mot de passe :</p>'
        + '<p style="text-align:center;margin:30px 0;">'
        + '<a href="' + resetUrl + '" style="background:#2F7D59;color:#fff;padding:16px 48px;border-radius:8px;text-decoration:none;font-weight:bold;font-size:16px;display:inline-block;">Définir mon mot de passe &#8594;</a>'
        + '</p>'
        + '<div style="background:#f5f9f7;padding:16px 20px;border-radius:8px;border-left:4px solid #2F7D59;margin:20px 0;">'
        + '<p style="margin:0;font-size:13px;color:#334155;"><strong>&#128274; Sécurité :</strong></p>'
        + '<ul style="margin:8px 0 0;padding-left:20px;font-size:13px;color:#475569;">'
        + '<li>Ce lien est <strong>à usage unique</strong> et expire dans <strong>24 heures</strong></li>'
        + '<li>Mot de passe : min. 8 caractères (majuscule + minuscule + chiffre + spécial)</li>'
        + '</ul></div>'
        + '<p style="color:#999;font-size:12px;text-align:center;border-top:1px solid #eee;padding-top:15px;">'
        + 'Cet email est envoyé automatiquement par le système de recrutement Talan.</p>'
        + '</div></div>';

    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
    mail.setToAddresses(new List<String>{ u.Email });
    mail.setSubject('Portail RH Talan — Définissez votre mot de passe');
    mail.setHtmlBody(html);
    mail.setSaveAsActivity(false);
    Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
    System.debug('Email bienvenue envoyé à ' + u.Email + ' avec lien: ' + resetUrl);
}
