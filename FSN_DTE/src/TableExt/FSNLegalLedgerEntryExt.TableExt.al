tableextension 50122 "FSN Legal Ledger Entry" extends "Legal Ledger Entry"
{
    fields
    {
        field(60000; "DTE AuthNumber"; Code[36])
        {
            Caption = 'DTE AuthNumber';
            DataClassification = ToBeClassified;
        }
        field(60001; "DTE Invoice"; Code[31])
        {
            Caption = 'DTE Invoice';
            DataClassification = ToBeClassified;
        }
        field(60002; "Signature Validation"; Text[50])
        {
            Caption = 'Signature Validation';
            DataClassification = ToBeClassified;
        }

    }
}
