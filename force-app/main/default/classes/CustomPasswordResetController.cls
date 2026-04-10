public with sharing class CustomPasswordResetController {
    @AuraEnabled
    public static void resetPassword(String email) {
        if (String.isBlank(email)) {
            throw new AuraHandledException('Veuillez saisir un email.');
        }

        // Chercher le User Community actif
        List<User> users = [
            SELECT Id, Username, Email, FirstName, UserType 
            FROM User 
            WHERE Email = :email 
            AND IsActive = true 
            AND UserType IN ('CspLitePortal', 'CustomerPortal', 'PowerCustomerSuccess')
            LIMIT 1
        ];

        // Fallback: chercher par Contact email
        if (users.isEmpty()) {
            List<Contact> contacts = [SELECT Id FROM Contact WHERE Email = :email LIMIT 1];
            if (!contacts.isEmpty()) {
                users = [
                    SELECT Id, Username, Email, FirstName, UserType 
                    FROM User 
                    WHERE ContactId = :contacts[0].Id 
                    AND IsActive = true 
                    LIMIT 1
                ];
            }
        }

        if (users.isEmpty()) {
            throw new AuraHandledException('Aucun compte portail trouvé avec cet email.');
        }

        try {
            User u = users[0];

            // Envoyer le lien de réinitialisation sécurisé Salesforce (token signé, expiration 24h)
            // Aucun mot de passe n'est généré ni transmis en clair
            System.resetPassword(u.Id, true);

            // Email d'information complémentaire (sans mot de passe)
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ email });
            mail.setSubject('Réinitialisation de votre mot de passe - Portail RH Talan');
            mail.setSaveAsActivity(false);

            String body = '<div style="font-family:Segoe UI,Arial,sans-serif; max-width:600px; margin:auto;">'
                + '<div style="background:linear-gradient(135deg,#2F7D59,#1a4d2e); padding:30px; text-align:center; border-radius:12px 12px 0 0;">'
                + '<h1 style="color:#fff; margin:0; font-size:24px;">Portail RH Talan</h1>'
                + '<p style="color:rgba(255,255,255,0.8); margin:8px 0 0; font-size:14px;">Réinitialisation du mot de passe</p>'
                + '</div>'
                + '<div style="background:#fff; padding:30px; border:1px solid #e0e0e0; border-radius:0 0 12px 12px;">'
                + '<p style="font-size:16px;">Bonjour <strong>' + (u.FirstName != null ? u.FirstName : '') + '</strong>,</p>'
                + '<p>Une demande de réinitialisation de mot de passe a été effectuée pour votre compte.</p>'
                + '<p style="background:#f0fdf4; border-left:4px solid #2F7D59; padding:14px 18px; border-radius:6px; font-size:14px; color:#166534;">'
                + '&#128274; Un <strong>lien sécurisé</strong> vient d&apos;être envoyé séparément par Salesforce.<br>'
                + 'Cliquez dessus pour définir votre nouveau mot de passe. Il expire dans <strong>24 heures</strong>.</p>'
                + '<p style="color:#dc2626; background:#fef2f2; border-left:4px solid #dc2626; padding:12px 16px; border-radius:6px; font-size:13px;">'
                + '&#9888; Si vous n&apos;avez pas demandé cette réinitialisation, '
                + 'votre compte est peut-être compromis. Contactez immédiatement le support.</p>'
                + '<p style="text-align:center; margin:25px 0;">'
                + '<a href="https://orgfarm-3ed211f8bb-dev-ed.develop.my.site.com/home2/s/loginp" '
                + 'style="background:#2F7D59; color:#fff; padding:14px 40px; border-radius:8px; text-decoration:none; font-weight:bold; font-size:15px; display:inline-block;">'
                + 'Aller à la connexion</a></p>'
                + '<p style="color:#999; font-size:12px; margin-top:30px; text-align:center; border-top:1px solid #eee; padding-top:15px;">'
                + 'Ne communiquez jamais votre mot de passe par email ou téléphone.<br>'
                + 'Talan ne vous demandera jamais votre mot de passe.</p>'
                + '</div></div>';

            mail.setHtmlBody(body);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });

        } catch (Exception e) {
            throw new AuraHandledException('Erreur : ' + e.getMessage());
        }
    }
}
