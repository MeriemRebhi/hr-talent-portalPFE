import { LightningElement, wire, track } from 'lwc';
import getCandidaturesByUser from '@salesforce/apex/ApplicationController.getCandidaturesByUser';

export default class MyApplications extends LightningElement {
    @track applications = [];
    @track isLoading = true;
    @track hasError = false;
    @track errorMessage = '';

    @wire(getCandidaturesByUser)
    wiredApplications({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.applications = data.map(app => ({
                ...app,
                fullName: (app.FirstName || '') + ' ' + (app.LastName || ''),
                hasScore: app.Score_Matching__c != null,
                formattedDate: app.CreatedDate
                    ? new Date(app.CreatedDate).toLocaleDateString('fr-FR')
                    : '',
                stageBadgeClass: this.getStageBadgeClass(app.StageName),
                scoreClass: this.getScoreClass(app.Score_Matching__c),
                scoreLabel: this.getScoreLabel(app.Score_Matching__c)
            }));
            this.hasError = false;
        } else if (error) {
            this.hasError = true;
            this.errorMessage = error.body ? error.body.message : 'Erreur de chargement.';
        }
    }

    get hasApplications() {
        return !this.isLoading && !this.hasError && this.applications.length > 0;
    }

    get isEmpty() {
        return !this.isLoading && !this.hasError && this.applications.length === 0;
    }

    getStageBadgeClass(stage) {
        if (!stage) return 'badge badge-default';
        const s = stage.toLowerCase();
        if (s === 'gaming') return 'badge badge-gaming';
        if (s === 'technique') return 'badge badge-technique';
        if (s === 'architecture') return 'badge badge-architecture';
        if (s.includes('rh') || s.includes('fit')) return 'badge badge-rhfit';
        if (s.includes('hired') || s.includes('recruté')) return 'badge badge-hired';
        if (s.includes('rejeté') || s.includes('closed') || s === 'rejected') return 'badge badge-rejected';
        return 'badge badge-default';
    }

    getScoreClass(score) {
        if (score == null) return 'score-none';
        if (score >= 80) return 'score-excellent';
        if (score >= 60) return 'score-good';
        if (score >= 40) return 'score-fair';
        return 'score-poor';
    }

    getScoreLabel(score) {
        if (score == null) return 'En attente d\'analyse';
        if (score >= 80) return 'Excellent profil';
        if (score >= 60) return 'Bon profil';
        if (score >= 40) return 'Profil moyen';
        return 'Profil insuffisant';
    }
}
