table 50102 "FSN Lote Invalidate"
{
    DataClassification = ToBeClassified;

    fields
    {
        field(10; "Transaction No."; Integer)
        {
            DataClassification = ToBeClassified;

        }
        field(20; "Store No."; Code[10])
        {
            DataClassification = ToBeClassified;

        }
        field(30; "Pos Terminal No."; Code[10])
        {
            DataClassification = ToBeClassified;

        }
        field(40; "Line No."; Integer)
        {
            DataClassification = ToBeClassified;
        }
        field(50; "Lot No."; Code[20])
        {
            DataClassification = ToBeClassified;

        }
        field(60; "Expiration Date"; Date)
        {
            DataClassification = ToBeClassified;

        }

        field(70; "Item No."; Code[20])
        {
            DataClassification = ToBeClassified;

        }
        field(80; "Quantity"; Decimal)
        {
            DataClassification = ToBeClassified;

        }
        field(90; "Date"; Date)
        {
            DataClassification = ToBeClassified;

        }
        field(100; Message; Text[250])
        {
            DataClassification = ToBeClassified;

        }
        field(110; Faltante; Decimal)
        {
            DataClassification = ToBeClassified;
        }

    }

    keys
    {
        key(Key1; "Store No.", "POS Terminal No.", "Transaction No.", "Line No.")
        {
            Clustered = true;
        }
    }

    var
        myInt: Integer;

    trigger OnInsert()
    begin

    end;

    trigger OnModify()
    begin

    end;

    trigger OnDelete()
    begin

    end;

    trigger OnRename()
    begin

    end;

}