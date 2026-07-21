table 50107 "FSN Vending Line"
{
    DataClassification = ToBeClassified;

    fields
    {
        field(1; "idMachine"; Integer)
        {
        }
        field(2; "idTransaction"; Integer)
        {
        }
        field(3; "lineNo"; Integer)
        {
        }
        field(4; "idProduct"; Code[20])
        {
        }
        field(5; "Description"; Text[100])
        {
        }
        field(6; "Unit Of Measure"; Code[50])
        {
        }
        field(7; "lot"; Code[50])
        {
        }
        field(8; "expirationDate"; Date)
        {
        }
        field(9; "quantity"; Decimal)
        {
        }
        field(10; "price"; Decimal)
        {
        }
        field(11; "priceCost"; Decimal)
        {
        }
    }

    keys
    {
        key(PK; "idMachine", "idTransaction", "lineNo")
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
        // Add changes to field groups here
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