/**
 * Business Card Scanner LWC — capture a business card image, extract contact
 * details with Einstein, and create or update a Salesforce Lead.
 *
 * @author Rajeev Shekhar
 */
import { LightningElement, api, track } from 'lwc';
import extractFromCard from '@salesforce/apex/BusinessCardController.extractFromCard';
import findLead from '@salesforce/apex/BusinessCardController.findLead';
import createLead from '@salesforce/apex/BusinessCardController.createLead';
import updateLead from '@salesforce/apex/BusinessCardController.updateLead';
import STRAWBERRY_LOGO from '@salesforce/resourceUrl/strawberryLogo';

export default class BusinessCardScanner extends LightningElement {
    logoUrl = STRAWBERRY_LOGO;
    @api recordId; // parent record context if needed
    @track leadId;
    acceptedFormats = ['.jpg', '.jpeg', '.png'];

    @track uploadedFileName;
    @track contentDocumentId;
    @track previewUrl;

    @track isProcessing = false;
    @track statusMessage;
    @track statusVariant = 'info'; // info | success | warning | error

    @track extracted;        // JSON from AI (object)
    @track aiFields = [];    // for pretty UI
    @track existingLead;     // existing Lead (if any)
    @track showCreateButton = false;

    // ------------- Getters -------------

    get isAnalyzeDisabled() {
        return !this.contentDocumentId || this.isProcessing;
    }

    get isClearDisabled() {
        return (
            !this.uploadedFileName &&
            !this.previewUrl &&
            !this.extracted &&
            !this.existingLead
        );
    }

    get statusClass() {
        // Example: "bcs-status slds-box slds-theme_success"
        return 'bcs-status slds-box slds-theme_' + this.statusVariant;
    }

    get leadRecordUrl() {
        return this.leadId ? `/lightning/r/Lead/${this.leadId}/view` : '';
    }

    get existingLeadUrl() {
        return this.existingLead ? `/lightning/r/Lead/${this.existingLead.Id}/view` : '';
    }

    // Once a Lead is saved, the process is complete — suppress the in-progress
    // status banner in favour of the completion panel.
    get showStatus() {
        return this.statusMessage && !this.leadId;
    }


    // ------------- Handlers -------------

    handleUploadFinished(event) {
        const files = event.detail.files;
        if (!files || !files.length) {
            return;
        }

        const file = files[0];
        this.uploadedFileName = file.name;
        this.contentDocumentId = file.documentId;
        this.previewUrl = '/sfc/servlet.shepherd/document/download/' + this.contentDocumentId;

        // reset state
        this.extracted = null;
        this.existingLead = null;
        this.aiFields = [];
        this.showCreateButton = false;

        this.statusVariant = 'info';
        this.statusMessage = 'Card image uploaded. Tap "Analyze with AI" to continue.';
    }

    handleClear() {
        this.uploadedFileName = null;
        this.contentDocumentId = null;
        this.previewUrl = null;
        this.extracted = null;
        this.existingLead = null;
        this.aiFields = [];
        this.showCreateButton = false;
        this.statusMessage = null;
        this.statusVariant = 'info';
    }

    handleAnalyze() {
        if (!this.contentDocumentId) {
            this.statusVariant = 'warning';
            this.statusMessage = 'Please upload a business card image first.';
            return;
        }

        this.isProcessing = true;
        this.statusVariant = 'info';
        this.statusMessage = 'Calling AI to extract information…';

        extractFromCard({ contentDocumentId: this.contentDocumentId })
            .then((rawJson) => {
                // rawJson is the JSON string from the AI model
                this.extracted = JSON.parse(rawJson);

                this.aiFields = [
                    { label: 'First Name', value: this.extracted.firstName || '—' },
                    { label: 'Last Name', value: this.extracted.lastName || '—' },
                    { label: 'Job Title', value: this.extracted.jobTitle || '—' },
                    { label: 'Company', value: this.extracted.company || '—' },
                    { label: 'Email', value: this.extracted.email || '—' },
                    { label: 'Phone', value: this.extracted.phone || '—' },
                    { label: 'Mobile', value: this.extracted.mobile || '—' },
                    { label: 'Website', value: this.extracted.website || '—' },
                    { label: 'Street', value: this.extracted.street || '—' },
                    { label: 'City', value: this.extracted.city || '—' },
                    { label: 'State', value: this.extracted.state || '—' },
                    { label: 'Postal Code', value: this.extracted.postalCode || '—' },
                    { label: 'Country', value: this.extracted.country || '—' },
                    { label: 'LinkedIn', value: this.extracted.linkedin || '—' }
                ];

                this.statusVariant = 'success';
                this.statusMessage = 'AI extraction complete. Checking for existing Leads…';

                return findLead({ email: this.extracted.email });
            })
            .then((lead) => {
                this.existingLead = lead;
                this.showCreateButton = !lead;

                if (lead) {
                    this.statusVariant = 'success';
                    this.statusMessage = 'Existing Lead found with this email.';
                } else {
                    this.statusVariant = 'info';
                    this.statusMessage = 'No existing Lead found. You can create a new Lead.';
                }
            })
            .catch((error) => {
                let msg = 'Unexpected error during analysis.';
                if (error && error.body && error.body.message) {
                    msg = error.body.message;
                } else if (error && error.message) {
                    msg = error.message;
                }
                this.statusVariant = 'error';
                this.statusMessage = msg;
            })
            .finally(() => {
                this.isProcessing = false;
            });
    }

    handleOverwriteLead() {
        if (!this.existingLead || !this.extracted) {
            return;
        }

        this.isProcessing = true;
        this.statusVariant = 'info';
        this.statusMessage = 'Updating existing Lead…';

        updateLead({
            extractedJson: JSON.stringify(this.extracted),
            existingLeadId: this.existingLead.Id
        })
            .then(() => {
                this.leadId = this.existingLead.Id;
                // End the flow cleanly: remove the duplicate card and create
                // option so the Lead can't be overwritten again by accident.
                this.existingLead = null;
                this.showCreateButton = false;
                this.statusVariant = 'success';
                this.statusMessage = 'Lead updated successfully.';
            })
            .catch((error) => {
                let msg = 'Error updating Lead.';
                if (error && error.body && error.body.message) {
                    msg = error.body.message;
                } else if (error && error.message) {
                    msg = error.message;
                }
                this.statusVariant = 'error';
                this.statusMessage = msg;
            })
            .finally(() => {
                this.isProcessing = false;
            });
    }

    handleCreateLead() {
        if (!this.extracted) {
            return;
        }

        this.isProcessing = true;
        this.statusVariant = 'info';
        this.statusMessage = 'Creating new Lead…';

        createLead({
            extractedJson: JSON.stringify(this.extracted)
        })
            .then((id) => {
                this.leadId = id;
                this.showCreateButton = false;
                this.statusVariant = 'success';
                this.statusMessage = 'Lead created successfully.';
            })
            .catch((error) => {
                let msg = 'Error creating Lead.';
                if (error && error.body && error.body.message) {
                    msg = error.body.message;
                } else if (error && error.message) {
                    msg = error.message;
                }
                this.statusVariant = 'error';
                this.statusMessage = msg;
            })
            .finally(() => {
                this.isProcessing = false;
            });
    }
}