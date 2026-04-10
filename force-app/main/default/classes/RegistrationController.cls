public with sharing class RegistrationController {
    @AuraEnabled
    public static void sendPortalResetEmail(String email) {
        if (String.isBlank(email)) {
            throw new AuraHandledException('Veuillez renseigner un email.');
        }
        // Chercher le Contact lié à cet email
        List<Contact> contacts = [SELECT Id FROM Contact WHERE Email = :email LIMIT 1];
        if (contacts.isEmpty()) {
            throw new AuraHandledException('Aucun candidat trouvé avec cet email.');
        }
        Contact c = contacts[0];
        // Chercher le User portail lié à ce contact
        List<User> users = [SELECT Id, Username, IsActive FROM User WHERE ContactId = :c.Id AND UserType = 'CustomerPortal' LIMIT 1];
        if (users.isEmpty()) {
            throw new AuraHandledException('Aucun accès portail trouvé pour ce candidat.');
        }
        User u = users[0];
        if (!u.IsActive) {
            throw new AuraHandledException('Le compte portail est inactif.');
        }
        // Envoyer l'email de réinitialisation de mot de passe
        System.resetPassword(u.Id, true);
    }
}
