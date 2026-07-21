table 50098 "FSN RifasDetalle"
{

    fields
    {
        field(100; "No Rifa"; Code[30])
        {
            Caption = 'Cod Raffle';
            TableRelation = "FSN Rifas".NoRifa;
        }
        field(150; Tipo; Option)
        {
            Caption = 'Type';
            Description = '0=Articulos,1=Marcas,2=Grupos Especiales';
            OptionMembers = Articulos,Marcas,"Grupos Especiales";
        }
        field(160; CodAtributo; Code[20])
        {
            Caption = 'Cod. Att.';
        }
        field(200; "Line No"; Integer)
        {
            Caption = 'Line';
        }
        field(300; CodSec; Code[30])
        {
            Caption = 'Code';
            TableRelation = IF (Tipo = CONST(Articulos)) Item."No."
            ELSE
            IF (Tipo = CONST("Grupos Especiales")) "LSC Item Special Groups".Code;
        }
        field(400; Descripcion; Text[50])
        {
            Caption = 'Description';
        }
        field(500; CantMin; Integer)
        {
            Caption = 'Qty. Min.';
        }
        field(600; ValorMin; Decimal)
        {
            Caption = 'Min. Amt.';
        }
        field(700; ConvertirUnidades; Boolean)
        {
        }
    }

    keys
    {
        key(Key1; "No Rifa", "Line No")
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

