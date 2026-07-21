table 50053 "FSN Coinsurance"
{
    //WVILLALTA 10.21             - C/AL to AL
    Caption = 'FSN Coinsurance';

    fields
    {
        field(10; "No."; Code[10])
        {
            Caption = 'No.';
        }
        field(20; Description; Text[30])
        {
            Caption = 'Description';
        }
        field(30; "Percent Benefit"; Decimal)
        {
            Caption = 'Percent Benefit';
            MaxValue = 100;
            MinValue = 0;
        }
        field(40; "Mail Address"; Text[80])
        {
            Caption = 'Mail Address';
            ExtendedDatatype = EMail;

            trigger OnValidate()
            var
                RemissionMgt1: Codeunit "FSN Remission Mgt.";
            begin
                IF "Mail Address" <> '' THEN
                    RemissionMgt1.ValidateEmail("Mail Address");
            end;
        }
        field(50; "Customer Filter"; Code[20])
        {
            Caption = 'Customer Filter';
            TableRelation = Customer."No." WHERE("FSN Insurer" = CONST(true));
        }
    }

    keys
    {
        key(Key1; "No.")
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "No.", Description, "Percent Benefit", "Customer Filter")
        {
        }
    }

    trigger OnDelete()
    begin
        CreateAction(2);
    end;

    trigger OnInsert()
    begin
        CreateAction(0);
    end;

    trigger OnModify()
    begin
        CreateAction(1);
    end;

    trigger OnRename()
    begin
        CreateAction(3);
    end;

    procedure CreateAction(Type: Integer)
    var
        RecRef: RecordRef;
        xRecRef: RecordRef;
        ActionsMgt: Codeunit "LSC Actions Management";
    begin
        //LS
        //Type: 0 = INSERT, 1 = MODIFY, 2 = DELETE, 3 = RENAME
        //
        RecRef.GETTABLE(Rec);
        xRecRef.GETTABLE(xRec);
        ActionsMgt.SetCalledByTableTrigger(false);
        ActionsMgt.CreateActionsByRecRef(RecRef, xRecRef, Type);
        RecRef.CLOSE;
        xRecRef.CLOSE;
    end;
}

