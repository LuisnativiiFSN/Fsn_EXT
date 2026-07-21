tableextension 50147 "FSN Purch Cr.Memo Header" extends "Purch. Cr. Memo Hdr."
{
    fields
    {
        field(50101; "FSN Withholding Tax Amount"; Decimal)
        {
            DataClassification = ToBeClassified;
            AutoFormatType = 1;
            Caption = 'FSN Withholding Tax Amount';

        }
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