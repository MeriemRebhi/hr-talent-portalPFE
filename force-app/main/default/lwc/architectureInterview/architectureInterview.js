import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getArchInterviewInfo from '@salesforce/apex/ArchitectureInterviewController.getArchInterviewInfo';
import requestReschedule from '@salesforce/apex/ArchitectureInterviewController.requestReschedule';

export default class ArchitectureInterview extends LightningElement {
    @track step = 'loading'; // loading | error | welcome | interview | done
    @track errorMessage = '';

    oppId;

    @track candidateName = '';
    @track jobTitle = '';
    @track meetLink = '';
    @track jitsiRoom = '';
    @track scheduledDate = null;
    @track duration = '';
    @track status = '';
    @track existingScore = null;

    @track rescheduleRequested = false;
    @track showRescheduleModal = false;
    @track rescheduleReason = '';
    @track isRescheduling = false;

    @wire(CurrentPageReference)
    setPageRef(ref) {
        if (ref && ref.state && ref.state.id) {
            this.oppId = ref.state.id;
        }
    }

    connectedCallback() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this._loadInterview(); }, 300);
    }

    get jitsiUrl() {
        if (this.jitsiRoom) {
            return `https://meet.jit.si/${this.jitsiRoom}`;
        }
        return this.meetLink || '';
    }

    get scheduledDateFormatted() {
        if (!this.scheduledDate) return '';
        try {
            const d = new Date(this.scheduledDate);
            const pad = (n) => String(n).padStart(2, '0');
            return `${pad(d.getDate())}/${pad(d.getMonth() + 1)}/${d.getFullYear()} a ${pad(d.getHours())}:${pad(d.getMinutes())}`;
        } catch (e) {
            return '';
        }
    }

    get durationLabel() {
        const map = { '30': '30 minutes', '45': '45 minutes', '60': '1 heure', '90': '1h30' };
        return map[this.duration] || (this.duration ? `${this.duration} min` : 'N/A');
    }

    get rescheduleButtonLabel() {
        return this.isRescheduling ? 'Envoi...' : 'Confirmer le report';
    }

    get canReschedule() {
        return !this.rescheduleRequested && this.scheduledDate;
    }

    get isStepLoading() { return this.step === 'loading'; }
    get isStepError() { return this.step === 'error'; }
    get isStepWelcome() { return this.step === 'welcome'; }
    get isStepInterview() { return this.step === 'interview'; }
    get isStepDone() { return this.step === 'done'; }

    async _loadInterview() {
        try {
            if (!this.oppId) {
                const url = new URL(window.location.href);
                this.oppId = url.searchParams.get('id');
            }
            if (!this.oppId) {
                this.errorMessage = 'Identifiant de candidature manquant dans l URL.';
                this.step = 'error';
                return;
            }

            const info = await getArchInterviewInfo({ oppId: this.oppId });
            this.candidateName = info.candidateName;
            this.jobTitle = info.jobTitle;
            this.meetLink = info.meetLink;
            this.jitsiRoom = info.jitsiRoom;
            this.scheduledDate = info.scheduledDate;
            this.duration = info.duration;
            this.status = info.status;
            this.existingScore = info.existingScore;
            this.rescheduleRequested = info.rescheduleRequested;

            if (info.alreadyCompleted) {
                this.step = 'done';
            } else if (info.isScheduled) {
                this.step = 'welcome';
            } else {
                this.errorMessage = 'Aucun entretien architecture n est planifie pour votre candidature.';
                this.step = 'error';
            }
        } catch (error) {
            this.errorMessage = error.body ? error.body.message : error.message;
            this.step = 'error';
        }
    }

    handleStartInterview() {
        this.step = 'interview';
    }

    handleMarkDone() {
        this.step = 'done';
    }

    handleShowReschedule() {
        this.showRescheduleModal = true;
    }

    handleCloseReschedule() {
        this.showRescheduleModal = false;
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    handleRescheduleReasonChange(event) {
        this.rescheduleReason = event.target.value;
    }

    async handleSubmitReschedule() {
        this.isRescheduling = true;
        try {
            await requestReschedule({
                oppId: this.oppId,
                reason: this.rescheduleReason
            });
            this.rescheduleRequested = true;
            this.showRescheduleModal = false;
        } catch (error) {
            this.errorMessage = error.body ? error.body.message : error.message;
        }
        this.isRescheduling = false;
    }
}
