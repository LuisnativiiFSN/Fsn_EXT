table 50081 "FSN RifasHistorialF"
{

    fields
    {
        field(100; "Rifa No"; Code[30])
        {
            Caption = 'Raffle No.';
            TableRelation = "FSN Rifas".NoRifa;
        }
        field(101; "Store No"; Code[10])
        {
            Caption = 'Store No.';
            TableRelation = "LSC Store"."No.";
        }
        field(102; "Receipt No"; Code[20])
        {
            Caption = 'Receipt No.';
        }
        field(103; Fecha; Date)
        {
            Caption = 'Date';
        }
        field(104; Ganador; Boolean)
        {
            Caption = 'Winner?';
        }
        field(105; NumGenerado; Decimal)
        {
            Caption = 'Generated No.';
        }
        field(106; Probabilidad; Decimal)
        {
            Caption = 'Probability';
        }

        field(107; "Replication Counter"; Integer)
        {
            Caption = 'Replication Counter', comment = 'ESP="Contador replicación"';
            DataClassification = CustomerContent;
            trigger OnValidate()
            var
                FSNRifasHistorialF: Record "FSN RifasHistorialF";
            begin
                FSNRifasHistorialF.SETCURRENTKEY("Replication Counter");
                IF FSNRifasHistorialF.FindLast() THEN
                    Rec."Replication Counter" := FSNRifasHistorialF."Replication Counter" + 1
                ELSE
                    Rec."Replication Counter" := 1;
            end;
        }
    }

    keys
    {
        key(Key1; "Rifa No", "Store No", "Receipt No")
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

    trigger OnDelete()
    begin
        CreateAction(2);
    end;

    trigger OnInsert()
    begin
        VALIDATE("Replication Counter");
        CreateAction(0);
    end;

    trigger OnModify()
    begin
        VALIDATE("Replication Counter");
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

