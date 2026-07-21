tableextension 50123 "FSN Cust Ledg Entry" extends "Cust. Ledger Entry"
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