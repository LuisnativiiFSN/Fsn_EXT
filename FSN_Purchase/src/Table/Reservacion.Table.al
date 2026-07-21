table 50049 "FSN Reservacion"
{

    fields
    {
        field(10; Item; Code[20])
        {
            TableRelation = Item."No.";
            ValidateTableRelation = false;

            trigger OnValidate()
            begin
                lItem.GET(Rec.Item);
                Description := lItem.Description;
                Reservar := TRUE;
                "Fecha Revervado" := TODAY;
            end;
        }
        field(11; Tienda; Code[10])
        {
            TableRelation = "LSC Store"."No.";
            ValidateTableRelation = false;
        }
        field(20; Description; Text[50])
        {
        }
        field(30; "Cant. a reservar"; Decimal)
        {
        }
        field(40; Reservar; Boolean)
        {
        }
        field(50; Comentario; Text[100])
        {
        }
        field(60; "Fecha Revervado"; Date)
        {
        }
        field(80; "Fecha Creado"; Date)
        {
        }
        field(90; "Hora Creado"; DateTime)
        {
        }
        field(100; "Ultima Modificacion"; DateTime)
        {
        }
        field(110; "Ultimo Usuario"; Code[50])
        {
        }
        field(120; "Usuario Creacion"; Code[50])
        {
        }
    }

    keys
    {
        key(Key1; Item, Tienda)
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
    }

    trigger OnInsert()
    begin
        "Fecha Creado" := TODAY;
        "Hora Creado" := CURRENTDATETIME;
        "Usuario Creacion" := USERID;
    end;

    trigger OnModify()
    begin
        "Ultima Modificacion" := CURRENTDATETIME;
        "Ultimo Usuario" := USERID;
    end;

    var
        lItem: Record Item;
}

