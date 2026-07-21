tableextension 50146 "FSN Job Queue Entry" extends "Job Queue Entry"
{
    fields
    {
        field(57000; "FSN Vendor Invoice No"; Text[35])
        {
            Caption = 'FSN Vendor Invoice No';
            DataClassification = ToBeClassified;
        }

        field(58000; "FSN HRC No"; Text[20])
        {
            Caption = 'FSN HRC No';
            DataClassification = ToBeClassified;
        }

        field(59000; "FSN Order No"; Text[20])
        {
            Caption = 'FSN Order No';
            DataClassification = ToBeClassified;
        }
    }

    var
        myInt: Integer;
}