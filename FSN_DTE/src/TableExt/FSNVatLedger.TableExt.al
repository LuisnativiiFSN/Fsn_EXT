/// <summary>
/// TableExtension FSN VAT Ledger (ID 50010) extends Record VAT ledger.
/// </summary>
tableextension 50065 "FSN VAT Ledger" extends "VAT ledger"
{
    fields
    {
        field(4; "DTE AuthNumber"; Code[36])
        {
            Caption = 'DTE AuthNumber';
        }
        field(7; "DTE Invoice"; Code[31])
        {
            Caption = 'DTE Invoice';
        }
        field(13; "Signature Validation"; Text[50])
        {
            Caption = 'Signature Validation';
            DataClassification = ToBeClassified;
        }
        field(50100; "Perception"; Decimal)
        {
            CaptionML = ENU = 'Perception', ESM = 'Percepción';

            DataClassification = ToBeClassified;
        }
    }

    trigger OnBeforeInsert()
    var
        transaction: Record "LSC Transaction Header";
        dteTransaction: Record "FSN DTE Transaction Header";
    begin
        if Type = Type::Sales then
            exit;

        transaction.SetRange("Store No.", Rec."Shortcut Dimension 1 Code");
        transaction.SetRange("POS Terminal No.", Rec.Dispositive);
        transaction.SetRange("Receipt No.", Rec."Document No.");
        if transaction.FindFirst() then
            dteTransaction.Get(transaction."Store No.", transaction."POS Terminal No.", transaction."Transaction No.");

        Rec."DTE AuthNumber" := dteTransaction."DTE AuthNumber";
        Rec."DTE Invoice" := dteTransaction."DTE Invoice";
        Rec."Signature Validation" := dteTransaction."Signature Validation";
    end;

    trigger OnInsert()
    var
        transaction: Record "LSC Transaction Header";
        dteTransaction: Record "FSN DTE Transaction Header";
    begin
        if Type = Type::Sales then
            exit;

        transaction.SetRange("Store No.", Rec."Shortcut Dimension 1 Code");
        transaction.SetRange("POS Terminal No.", Rec.Dispositive);
        transaction.SetRange("Receipt No.", Rec."Document No.");
        if transaction.FindFirst() then
            dteTransaction.Get(transaction."Store No.", transaction."POS Terminal No.", transaction."Transaction No.");

        Rec."DTE AuthNumber" := dteTransaction."DTE AuthNumber";
        Rec."DTE Invoice" := dteTransaction."DTE Invoice";
        Rec."Signature Validation" := dteTransaction."Signature Validation";
    end;
}