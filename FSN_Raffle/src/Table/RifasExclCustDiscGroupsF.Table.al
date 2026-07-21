table 50082 "FSN Rif. Excl. Cust Disc Group"
{

    fields
    {
        field(1; RifaNo; Code[30])
        {
            Caption = 'Raffle Code';
            TableRelation = "FSN Rifas".NoRifa;
        }
        field(2; CustDiscGrp; Code[20])
        {
            Caption = 'Cust. Disc. Group Code';
            TableRelation = "Customer Discount Group".Code;
        }
    }

    keys
    {
        key(Key1; RifaNo, CustDiscGrp)
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
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
        ActionsMgt.SetCalledByTableTrigger(TRUE);
        ActionsMgt.CreateActionsByRecRef(RecRef, xRecRef, Type);
        RecRef.CLOSE;
        xRecRef.CLOSE;
    end;
}

