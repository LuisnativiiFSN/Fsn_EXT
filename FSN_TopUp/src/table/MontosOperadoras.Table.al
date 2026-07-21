table 50087 "FSN Montos Operadoras"
{
    fields
    {
        field(10; ID; Code[10])
        {
            Caption = 'Id', comment = 'ESP="Identificador"';
            DataClassification = CustomerContent;
        }
        field(20; Operador; Text[100])
        {
            Caption = 'Operador', comment = 'ESP="Operador"';
            TableRelation = "FSN Operadoras Telefonicas".Nombre;
            DataClassification = CustomerContent;
        }
        field(30; Monto; Decimal)
        {
            Caption = 'Amount', comment = 'ESP="Monto"';
            DataClassification = CustomerContent;
        }
        field(40; Activo; Boolean)
        {
            Caption = 'Active', comment = 'ESP="Activo"';
            DataClassification = CustomerContent;
        }
        field(50; Epines; Integer)
        {
            Caption = 'Epines', comment = 'ESP="Epines"';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(Key1; ID)
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
    }
}

