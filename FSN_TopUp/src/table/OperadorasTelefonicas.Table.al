table 50088 "FSN Operadoras Telefonicas"
{

    fields
    {
        field(10; ID; Code[10])
        {
            Caption = 'Id', comment = 'ESP="Identificador"';
            DataClassification = CustomerContent;
        }
        field(20; Nombre; Text[100])
        {
            Caption = 'Name', comment = 'ESP="Nombre"';
            DataClassification = CustomerContent;
        }
        field(30; "No. Producto"; Code[20])
        {
            Caption = 'Product No.', comment = 'ESP="No. Producto"';
            TableRelation = Item."No.";
            DataClassification = CustomerContent;
        }
        field(40; "Url Consulta"; Text[250])
        {
            Caption = 'Url query', comment = 'ESP="Url Consulta"';
            DataClassification = CustomerContent;
        }
        field(50; "Url Recarga"; Text[250])
        {
            Caption = 'Url recharge', comment = 'ESP="Url Recarga"';
            DataClassification = CustomerContent;
        }
        field(60; "Precio e-pin"; Decimal)
        {
            Caption = 'Price e-pin', comment = 'ESP="Precio e-pin"';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(Key1; ID)
        {
            Clustered = true;
        }
        key(F1; "No. Producto") { }
    }

    fieldgroups
    {
        fieldgroup(DropDown; Nombre)
        {
        }
    }
}

