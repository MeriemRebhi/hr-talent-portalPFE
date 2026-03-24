public with sharing class CustomPasswordResetController {
    @AuraEnabled
    public static void resetPassword(String email) {
        List<User> users = [SELECT Id FROM User WHERE Email = :email AND IsActive = true LIMIT 1];
        if (users.isEmpty()) {
            throw new AuraHandledException('Aucun utilisateur actif trouvé avec cet email.');
        }
        try {
            System.resetPassword(users[0].Id, true);
        } catch (Exception e) {
            throw new AuraHandledException('Erreur lors de la réinitialisation du mot de passe : ' + e.getMessage());
        }
    }
}
