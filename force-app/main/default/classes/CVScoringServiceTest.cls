/**
 * Test Classes pour CVScoringService
 * Placeholder pour les tests futurs
 */
@isTest
private class CVScoringServiceTest {

    @testSetup
    static void setup() {
        // Tests à implémenter après la création des Custom Settings
    }

    @isTest
    static void testLeadCreation() {
        Lead testLead = new Lead();
        testLead.FirstName = 'Test';
        testLead.LastName = 'User';
        testLead.Email = 'test@example.com';
        testLead.Company = 'Test Co';
        insert testLead;
        
        System.assertNotEquals(null, testLead.Id, 'Lead doit être créé');
    }
}
