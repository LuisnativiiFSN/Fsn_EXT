page 50125 "FSN Sales Journal SOAP"
{
    Caption = 'FSN Sales Journal SOAP';
    DelayedInsert = true;
    DeleteAllowed = false;
    InsertAllowed = true;
    ModifyAllowed = false;
    PageType = List;
    SourceTable = "Gen. Journal Line";
    UsageCategory = None;

    layout
    {
        area(content)
        {
            field(CurrentJnlTemplateName; CurrentJnlTemplateName)
            {
                ApplicationArea = All;
                Caption = 'Journal Template Name';
            }
            field(CurrentJnlBatchName; CurrentJnlBatchName)
            {
                ApplicationArea = All;
                Caption = 'Journal Batch Name';
            }
            repeater(Lines)
            {
                field("Posting Date"; Rec."Posting Date")
                {
                    ApplicationArea = All;
                }
                field("Document Date"; Rec."Document Date")
                {
                    ApplicationArea = All;
                }
                field("Document Type"; Rec."Document Type")
                {
                    ApplicationArea = All;
                }
                field("Document No."; Rec."Document No.")
                {
                    ApplicationArea = All;
                }
                field("Incoming Document Entry No."; Rec."Incoming Document Entry No.")
                {
                    ApplicationArea = All;
                }
                field("External Document No."; Rec."External Document No.")
                {
                    ApplicationArea = All;
                }
                field("Account Type"; Rec."Account Type")
                {
                    ApplicationArea = All;
                }
                field("Account No."; Rec."Account No.")
                {
                    ApplicationArea = All;
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                }
                field("Salespers./Purch. Code"; Rec."Salespers./Purch. Code")
                {
                    ApplicationArea = All;
                }
                field("Campaign No."; Rec."Campaign No.")
                {
                    ApplicationArea = All;
                }
                field("Currency Code"; Rec."Currency Code")
                {
                    ApplicationArea = All;
                }
                field("Gen. Posting Type"; Rec."Gen. Posting Type")
                {
                    ApplicationArea = All;
                }
                field("Gen. Bus. Posting Group"; Rec."Gen. Bus. Posting Group")
                {
                    ApplicationArea = All;
                }
                field("Gen. Prod. Posting Group"; Rec."Gen. Prod. Posting Group")
                {
                    ApplicationArea = All;
                }
                field("VAT Bus. Posting Group"; Rec."VAT Bus. Posting Group")
                {
                    ApplicationArea = All;
                }
                field("VAT Prod. Posting Group"; Rec."VAT Prod. Posting Group")
                {
                    ApplicationArea = All;
                }
                field(Amount; Rec.Amount)
                {
                    ApplicationArea = All;
                }
                field("Debit Amount"; Rec."Debit Amount")
                {
                    ApplicationArea = All;
                }
                field("Credit Amount"; Rec."Credit Amount")
                {
                    ApplicationArea = All;
                }
                field("Tax Liable"; Rec."Tax Liable")
                {
                    ApplicationArea = All;
                }
                field("Tax Area Code"; Rec."Tax Area Code")
                {
                    ApplicationArea = All;
                }
                field("Tax Group Code"; Rec."Tax Group Code")
                {
                    ApplicationArea = All;
                }
                field("VAT Amount"; Rec."VAT Amount")
                {
                    ApplicationArea = All;
                }
                field("VAT Difference"; Rec."VAT Difference")
                {
                    ApplicationArea = All;
                }
                field("Bal. VAT Amount"; Rec."Bal. VAT Amount")
                {
                    ApplicationArea = All;
                }
                field("Bal. VAT Difference"; Rec."Bal. VAT Difference")
                {
                    ApplicationArea = All;
                }
                field("Bal. Account Type"; Rec."Bal. Account Type")
                {
                    ApplicationArea = All;
                }
                field("Bal. Account No."; Rec."Bal. Account No.")
                {
                    ApplicationArea = All;
                }
                field("Bal. Gen. Posting Type"; Rec."Bal. Gen. Posting Type")
                {
                    ApplicationArea = All;
                }
                field("Bal. Gen. Bus. Posting Group"; Rec."Bal. Gen. Bus. Posting Group")
                {
                    ApplicationArea = All;
                }
                field("Bal. Gen. Prod. Posting Group"; Rec."Bal. Gen. Prod. Posting Group")
                {
                    ApplicationArea = All;
                }
                field("Bal. VAT Bus. Posting Group"; Rec."Bal. VAT Bus. Posting Group")
                {
                    ApplicationArea = All;
                }
                field("Bal. VAT Prod. Posting Group"; Rec."Bal. VAT Prod. Posting Group")
                {
                    ApplicationArea = All;
                }
                field("Bill-to/Pay-to No."; Rec."Bill-to/Pay-to No.")
                {
                    ApplicationArea = All;
                }
                field("Ship-to/Order Address Code"; Rec."Ship-to/Order Address Code")
                {
                    ApplicationArea = All;
                }
                field("Payment Terms Code"; Rec."Payment Terms Code")
                {
                    ApplicationArea = All;
                }
                field("Due Date"; Rec."Due Date")
                {
                    ApplicationArea = All;
                }
                field("Pmt. Discount Date"; Rec."Pmt. Discount Date")
                {
                    ApplicationArea = All;
                }
                field("Payment Discount %"; Rec."Payment Discount %")
                {
                    ApplicationArea = All;
                }
                field("Applies-to Doc. Type"; Rec."Applies-to Doc. Type")
                {
                    ApplicationArea = All;
                }
                field("Applies-to Doc. No."; Rec."Applies-to Doc. No.")
                {
                    ApplicationArea = All;
                }
                field("Applies-to ID"; Rec."Applies-to ID")
                {
                    ApplicationArea = All;
                }
                field("On Hold"; Rec."On Hold")
                {
                    ApplicationArea = All;
                }
                field("Reason Code"; Rec."Reason Code")
                {
                    ApplicationArea = All;
                }
                field(Correction; Rec.Correction)
                {
                    ApplicationArea = All;
                }
                field(Comment; Rec.Comment)
                {
                    ApplicationArea = All;
                }
                field("Direct Debit Mandate ID"; Rec."Direct Debit Mandate ID")
                {
                    ApplicationArea = All;
                }
                field("Shortcut Dimension 1 Code"; Rec."Shortcut Dimension 1 Code")
                {
                    ApplicationArea = All;
                }
                field("Shortcut Dimension 2 Code"; Rec."Shortcut Dimension 2 Code")
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        if CurrentJnlTemplateName <> '' then
            Rec."Journal Template Name" := CurrentJnlTemplateName;
        if CurrentJnlBatchName <> '' then
            Rec."Journal Batch Name" := CurrentJnlBatchName;
    end;

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    var
        GenJnlBatch: Record "Gen. Journal Batch";
        GenJnlTemplate: Record "Gen. Journal Template";
    begin
        if CurrentJnlTemplateName = '' then
            Error(MissingTemplateErr);
        if CurrentJnlBatchName = '' then
            Error(MissingBatchErr);

        GenJnlTemplate.Get(CurrentJnlTemplateName);
        if GenJnlTemplate.Type <> GenJnlTemplate.Type::Sales then
            Error(InvalidTemplateTypeErr, CurrentJnlTemplateName, GenJnlTemplate.Type);
        if GenJnlTemplate.Recurring then
            Error(RecurringTemplateErr, CurrentJnlTemplateName);

        GenJnlBatch.Get(CurrentJnlTemplateName, CurrentJnlBatchName);

        Rec.Validate("Journal Template Name", CurrentJnlTemplateName);
        Rec.Validate("Journal Batch Name", CurrentJnlBatchName);
        if Rec."Line No." = 0 then
            Rec."Line No." := GetNextLineNo(CurrentJnlTemplateName, CurrentJnlBatchName);

        if Rec."Posting Date" = 0D then
            Rec.Validate("Posting Date", WorkDate());
        if Rec."Document Date" = 0D then
            Rec.Validate("Document Date", Rec."Posting Date");

        Rec.TestField("Document No.");
        Rec.TestField("Account No.");

        Rec."Source Code" := GenJnlTemplate."Source Code";
        if Rec."Reason Code" = '' then
            Rec."Reason Code" := GenJnlBatch."Reason Code";
        if (Rec."Bal. Account No." = '') and (GenJnlBatch."Bal. Account No." <> '') then begin
            Rec.Validate("Bal. Account Type", GenJnlBatch."Bal. Account Type");
            Rec.Validate("Bal. Account No.", GenJnlBatch."Bal. Account No.");
        end;

        exit(true);
    end;

    local procedure GetNextLineNo(JournalTemplateName: Code[10]; JournalBatchName: Code[10]): Integer
    var
        GenJnlLine: Record "Gen. Journal Line";
    begin
        GenJnlLine.LockTable();
        GenJnlLine.SetRange("Journal Template Name", JournalTemplateName);
        GenJnlLine.SetRange("Journal Batch Name", JournalBatchName);
        if GenJnlLine.FindLast() then
            exit(GenJnlLine."Line No." + 10000);

        exit(10000);
    end;

    var
        CurrentJnlTemplateName: Code[10];
        CurrentJnlBatchName: Code[10];
        MissingTemplateErr: Label 'Debe especificar CurrentJnlTemplateName para crear la linea del diario de ventas.';
        MissingBatchErr: Label 'Debe especificar CurrentJnlBatchName para crear la linea del diario de ventas.';
        InvalidTemplateTypeErr: Label 'La plantilla %1 es de tipo %2. El servicio solo admite plantillas de tipo Ventas.';
        RecurringTemplateErr: Label 'La plantilla %1 es periodica y no se puede usar con este servicio SOAP.';
}
