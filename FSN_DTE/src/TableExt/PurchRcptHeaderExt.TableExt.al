tableextension 50103 "FSN Purch Receipt Header" extends "Purch. Rcpt. Header"
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
        }
        field(60001; "DTE Invoice"; Code[31])
        {
            Caption = 'DTE Invoice';
        }
        field(60002; "Signature Validation"; Text[50])
        {
            Caption = 'Signature Validation';
            DataClassification = ToBeClassified;
        }
        field(60011; "No. Credit Memo Associated"; Text[60])
        {
            Caption = 'No. Credit Memo Associated';
            DataClassification = ToBeClassified;

        }

    }
}