table 50062 "FSN Sell Out Value Entry"
{
    fields
    {
        field(10; "Store No."; Code[10])
        {
            TableRelation = "LSC Store"."No.";
            ValidateTableRelation = false;
        }
        field(20; "POS Terminal No."; Code[10])
        {
            TableRelation = "LSC POS Terminal"."No.";
            ValidateTableRelation = false;
        }
        field(30; "Transaction No."; Integer)
        {
        }
        field(40; "Line No."; Integer)
        {
            Description = 'Line POS trans. Line and POS Trans. Periodic Disc.';
        }
        field(50; "Offer No."; Code[20])
        {
        }
        field(60; "Offer Type"; Enum "LSC Trans. Disc. Ent Offer Typ")
        {

        }
        field(70; "Item No."; Code[20])
        {
            TableRelation = Item."No.";
            ValidateTableRelation = false;
        }
        field(80; "Sell Out Amount"; Decimal)
        {
        }
        field(90; "Replication Counter"; Integer)
        {

            trigger OnValidate()
            var
                CounterSellOutTable: Record "FSN Sell Out Value Entry";
            begin
                CounterSellOutTable.RESET;
                CounterSellOutTable.SETCURRENTKEY("Replication Counter");
                IF CounterSellOutTable.FINDLAST THEN
                    "Replication Counter" := CounterSellOutTable."Replication Counter" + 1
                ELSE
                    "Replication Counter" := 1;
            end;
        }
        field(100; Date; Date)
        {
        }
        field(101; "Sell Out Type"; Enum "FSN Sell Out Value Type")
        {
            Caption = 'Sell Out Type';
        }
        field(102; "Value Sell Out"; Decimal)
        {
            Caption = 'Value Sell Out';
            MaxValue = 100;
            MinValue = 0;
        }
        field(103; "Receipt No."; code[20])
        {
            DataClassification = ToBeClassified;
        }
    }

    keys
    {
        key(Key1; "Store No.", "POS Terminal No.", "Transaction No.", "Line No.", "Offer No.", "Offer Type")
        {
            Clustered = true;
        }
        key(Key2; "Replication Counter")
        {
        }
    }

    fieldgroups
    {
    }

    trigger OnInsert()
    begin
        IF Date = 0D THEN
            Date := TODAY;
        VALIDATE("Replication Counter");
    end;

    trigger OnModify()
    begin
        VALIDATE("Replication Counter");
    end;

    trigger OnRename()
    begin
        VALIDATE("Replication Counter");
    end;
}

