table 50020 "FSN Replen. Template Matrix"

{

    Permissions = TableData "Purch. Inv. Header" = rim;
    fields
    {
        field(10; "Replenishment Template Code"; Code[20])
        {
        }
        field(20; "Batch No."; Code[10])
        {
            Caption = 'Batch No.';
        }
        field(30; "Line No."; Integer)
        {
        }
        field(40; "Barcode No."; Code[20])
        {
        }
        field(50; "Item No."; Code[20])
        {
        }
        field(60; Description; Text[50])
        {
        }
        field(70; "Direct Unit Cost"; Decimal)
        {
        }
        field(80; "Vendor No."; Code[20])
        {
        }
        field(90; "Vendor Name"; Text[100])
        {
        }
        field(100; "Attrib 1 Code"; Text[30])
        {
        }
        field(110; "Qty. per Unit of Measure"; Decimal)
        {
        }
        field(120; "Purc. Unit of Measure"; Code[10])
        {
        }
    }

    keys
    {
        key(Key1; "Replenishment Template Code", "Batch No.", "Line No.")
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
    }
}

