table 50097 "FSN Rifas"
{

    fields
    {
        field(100; NoRifa; Code[30])
        {
            Caption = 'Rifas No.';
        }
        field(200; Descripcion; Text[50])
        {
            Caption = 'Description';
        }
        field(300; Tipo; Option)
        {
            Caption = 'Type';
            Description = '0=Articulos,2=Grupos Especiales';
            OptionMembers = Articulos,"Grupos Especiales";
        }
        field(301; TipoDisparador; Option)
        {
            OptionCaption = ' ,Code Generator';
            OptionMembers = " ","Code Generator";

            trigger OnValidate()
            var
                lText001: Label 'Debe especificar el No. Serie antes, Rifa tipo: Generador de código.';
            begin
            end;
        }
        field(302; NoSerie; Code[10])
        {
            TableRelation = "No. Series".Code;
        }
        field(303; "Print Extra"; Code[10])
        {
            Caption = 'Print. Setup Header';
            TableRelation = "LSC POS Print Setup Header"."Setup ID";
        }
        field(304; "Print Extra Perdedor"; Code[10])
        {
            Caption = 'Print Extra Perdedor';
            TableRelation = "LSC POS Print Setup Header"."Setup ID";
        }
        field(400; CodAtributo; Code[20])
        {
            Caption = 'Attribute';
            TableRelation = "LSC Attribute"."Code";

            trigger OnValidate()
            begin
                IF Rec.Tipo <> Rec.Tipo::"Grupos Especiales" THEN
                    CodAtributo := '';
            end;
        }
        field(401; ItemLink; Code[20])
        {
            Caption = 'No. Producto vinculado';
            TableRelation = Item."No.";
        }
        field(500; FechaInicio; Date)
        {
            Caption = 'Starting Date';
        }
        field(600; FechaFin; Date)
        {
            Caption = 'Ending Date';
        }
        field(700; HoraInicio; Time)
        {
            Caption = 'Starting Hour';
        }
        field(800; HoraFin; Time)
        {
            Caption = 'Ending Hour';
        }
        field(900; VIP; Boolean)
        {
            Description = 'Determina si solo participan clientes con membresia';
        }
        field(901; ConfirmarParticipar; Boolean)
        {
            Caption = 'Confirmar participacion';
        }
        field(902; MultiplicarImpresion; Boolean)
        {
        }
        field(1000; CondMinimas; Integer)
        {
            Caption = 'Min. Cond.';
        }
        field(1100; ValorMinimo; Decimal)
        {
            Caption = 'Min. Amt.';
        }
        field(1200; ImprimirTicketPierde; Boolean)
        {
            Caption = 'Print Missing Ticket';
        }
        field(1400; Linea1Gana; Text[30])
        {
            Caption = 'Winner Line 1';
        }
        field(1500; Linea2Gana; Text[30])
        {
            Caption = 'Winner Line 2';
        }
        field(1600; Linea3Gana; Text[30])
        {
            Caption = 'Winner Line 3';
        }
        field(1700; Linea1Pierde; Text[30])
        {
            Caption = 'Missed Line 1';
        }
        field(1800; Linea2Pierde; Text[30])
        {
            Caption = 'Missed Line 2';
        }
        field(1900; Linea3Pierde; Text[30])
        {
            Caption = 'Missed Line 3';
        }
        field(2000; ImprimirCond; Boolean)
        {
            Caption = 'Print Raffle Conditions';
        }
        field(2100; Linea1Cond; Text[40])
        {
            Caption = 'Cond. Line 1';
        }
        field(2200; Linea2Cond; Text[40])
        {
            Caption = 'Cond. Line 2';
        }
        field(2300; Linea3Cond; Text[40])
        {
            Caption = 'Cond. Line 3';
        }
        field(2400; Linea4Cond; Text[40])
        {
            Caption = 'Cond. Line 4';
        }
        field(2500; Linea5Cond; Text[40])
        {
            Caption = 'Cond. Line 5';
        }
        field(2600; Linea6Cond; Text[40])
        {
            Caption = 'Cond. Line 6';
        }
        field(2700; Linea7Cond; Text[40])
        {
            Caption = 'Cond. Line 7';
        }
        field(2800; Linea8Cond; Text[40])
        {
            Caption = 'Cond. Line 8';
        }
        field(2900; Linea9Cond; Text[40])
        {
            Caption = 'Cond. Line 9';
        }
        field(3000; Linea10Cond; Text[40])
        {
            Caption = 'Cond. Line 10';
        }
        field(3100; Imagen; text[250])
        {
            Caption = 'Image';
        }
        field(3200; OffValidate; Boolean)
        {
            Caption = 'Off Validate';
        }
    }

    keys
    {
        key(Key1; NoRifa)
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
        ValidateRecord(Rec);
        CreateAction(0);
    end;

    trigger OnModify()
    begin
        ValidateRecord(Rec);
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

    procedure ValidateRecord("RECORD": Record "FSN Rifas")
    var
        lText001: Label 'El campo No. Series no puede estar vacío si el disparador es tipo Generador de Código';
        lText002: Label 'El campo Impresión Extra no puede estar vacío si el disparador es tipo Generador de Código';
    begin
        IF (Rec.TipoDisparador = Rec.TipoDisparador::"Code Generator") AND (NoSerie = '') THEN
            ERROR(lText001);
        IF (Rec.TipoDisparador = Rec.TipoDisparador::"Code Generator") AND ("Print Extra" = '') THEN
            ERROR(lText002);
    end;
}

