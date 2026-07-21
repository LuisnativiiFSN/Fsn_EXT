table 50104 "FSN External Item Entry"
{
    Caption = 'FSN External Item Entry';
    DataClassification = ToBeClassified;

    fields
    {
        field(1; "Entry No."; Integer)
        {

        }
        field(2; "Item No."; Code[20]) { }
        field(3; "Posting Date"; Date) { }
        field(4; "Entry Type"; Code[20]) { }
        field(5; "Source No."; Code[20]) { }
        field(6; "Document No."; Code[20]) { }
        field(7; "Description"; Text[200]) { }
        field(8; "Location Code"; Code[20]) { }
        field(9; "Location Description"; Text[50]) { }
        field(10; "Quantity"; Decimal)
        {
            DecimalPlaces = 0 : 5;
        }
        field(11; "Document Date"; Date) { }
        field(12; "External Document No."; Code[20]) { }
        field(13; "Order Line No."; Integer) { }
        field(14; "Unit of Measure Code"; Code[20]) { }
        field(15; "Lot No."; Code[20]) { }
        field(16; "Expiration Date"; Date) { }
        field(17; "Return Reason Code"; Text[200]) { }
        field(18; "systemCreatedByEBS"; Code[20]) { }
        field(19; "systemCreatedEBS"; DateTime) { }
        field(20; "systemModifyByEBS"; Code[20]) { }
        field(21; "No. Mov. BC"; Integer) { }
        field(22; "Done"; Boolean) { }
        field(23; "Date"; Date) { }
        field(24; "Last error"; Text[250]) { }
        field(25; "Entry Type Name"; Text[50]) { }
        field(26; "Subinventoy"; Code[20]) { }
        field(27; "Stock Locator"; Code[20]) { }
        field(28; "Transfer Subinventory"; Code[20]) { }
        field(29; "Transfer Stock Locator"; Code[20]) { }
        field(30; "Origin"; Text[50]) { }
        field(31; "Journal Template Name"; Code[10]) { }
        field(32; "Journal Batch Name"; Code[20]) { }
        field(33; "Apply Entry"; Boolean) { }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
    }
}