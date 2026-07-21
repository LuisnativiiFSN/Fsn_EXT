tableextension 50124 "FSN Vendor Ledger Entry" extends "Vendor Ledger Entry"
{
    fields
    {
        field(50000; "FSN Comment"; Text[250])
        {
            Caption = 'Comment';
            DataClassification = ToBeClassified;
        }
    }

    var
        myInt: Integer;
}