table 50105 "FSN External Catalog"
{
    Caption = 'FSN External Catalog';
    DataClassification = ToBeClassified;

    fields
    {
        field(1; "No."; Integer)
        {
            AutoIncrement = true;
        }
        field(2; "Catalog Name"; Option)
        {
            OptionCaption = 'Entry Type,Location Code';
            OptionMembers = "Entry Type","Location Code";
        }
        field(3; "EBS Value"; Code[20]) { }
        field(4; "BC Entry Type"; Enum "Item Ledger Entry Type") { }
        field(5; "BC Location Code"; Code[20])
        {
            TableRelation = Location;
        }
        field(6; "Skip Entry"; Boolean) { }
        field(7; "EBS Entry Type Name"; Text[100]) { }
        field(8; "BC Document Type"; Enum "Item Ledger Document Type") { }
    }

    keys
    {
        key(PK; "No.")
        {
            Clustered = true;
        }
    }
}