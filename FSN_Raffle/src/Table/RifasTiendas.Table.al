table 50099 "FSN RifasTiendas"
{

    fields
    {
        field(100; "No Rifa"; Code[30])
        {
            Caption = 'Raffle No.';
            TableRelation = "FSN Rifas".NoRifa;
        }
        field(200; "Store No"; Code[10])
        {
            Caption = 'Store No.';
            TableRelation = "LSC Store"."No.";
        }
        field(300; Probabilidad; Decimal)
        {
            Caption = 'Probability';
        }
        field(301; ParametrosDiarios; Boolean)
        {
            Caption = 'Daily Parameters';
        }
        field(302; PremiosTotales; Integer)
        {
            Caption = 'Total Prizes';
        }
        field(303; PremiosOtorgados; Integer)
        {
            Caption = 'Prizes Granted';
        }
    }

    keys
    {
        key(Key1; "No Rifa", "Store No")
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

