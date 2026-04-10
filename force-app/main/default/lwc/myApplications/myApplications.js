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
            this.applications = data.map(app => {
                const stageIdx = this.getStageIndex(app.StageName, app.LeadStatus);
                return {
                    ...app,
                    fullName: (app.FirstName || '') + ' ' + (app.LastName || ''),
                    hasScore: app.Score_Matching__c != null,
                    formattedDate: app.CreatedDate
                        ? new Date(app.CreatedDate).toLocaleDateString('fr-FR')
                        : '',
                    displayStage: app.StageName || 'En cours',
                    stageBadgeClass: this.getStageBadgeClass(app.StageName),
                    scoreClass: this.getScoreClass(app.Score_Matching__c),
                    scoreLabel: this.getScoreLabel(app.Score_Matching__c),
                    progressSteps: this.computeProgressSteps(stageIdx),
                    trackFillClass: 'track-fill fill-' + [0, 25, 50, 75, 100][stageIdx]
                };
            });
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

    getStageIndex(stageName, leadStatus) {
        if (stageName) {
            const s = stageName.toLowerCase().trim();
            if (s === 'gaming') return 0;
            if (s === 'technique') return 1;
            if (s === 'architecture') return 2;
            if (s === 'rh fit') return 3;
            if (s.includes('closed')) return 4;
        }
        return 0;
    }

    computeProgressSteps(currentIdx) {
        const stages = ['Gaming', 'Technique', 'Architecture', 'RH Fit', 'Terminé'];
        return stages.map((label, i) => ({
            key: String(i),
            label,
            stepNum: i + 1,
            isCompleted: i < currentIdx,
            isNotCompleted: i >= currentIdx,
            circleCss: i < currentIdx
                ? 'step-circle step-done'
                : (i === currentIdx ? 'step-circle step-current' : 'step-circle step-pending'),
            labelCss: i < currentIdx
                ? 'step-lbl lbl-done'
                : (i === currentIdx ? 'step-lbl lbl-current' : 'step-lbl lbl-pending')
        }));
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
