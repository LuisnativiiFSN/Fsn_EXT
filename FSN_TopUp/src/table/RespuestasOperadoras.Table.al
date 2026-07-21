table 50090 "FSN Respuestas Operadoras"
{

    fields
    {
        field(1; ID; code[10])
        {
            Caption = 'Id', comment = 'ESP="Identificador"';
            DataClassification = ToBeClassified;
        }
        field(2; Operador; text[15])
        {
            Caption = 'Operador', comment = 'ESP="Operador"';
            DataClassification = ToBeClassified;
        }
        field(3; "Codigo Respuesta"; text[15])
        {
            Caption = 'Response Code', comment = 'ESP="Código Respuesta"';
            DataClassification = ToBeClassified;
        }
        field(4; Descripcion; text[250])
        {
            DataClassification = ToBeClassified;
            Caption = 'Description', comment = 'ESP="Descripción"';
        }
    }

    keys
    {
        key(Key1; ID)
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