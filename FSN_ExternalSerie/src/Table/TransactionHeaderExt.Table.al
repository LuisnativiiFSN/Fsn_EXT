table 50048 "FSN Transaction Header Ext"
{

    fields
    {
        field(1; "Store No."; Code[10])
        {
        }
        field(2; "POS Terminal No."; Code[10])
        {
        }
        field(3; "Transaction No."; Integer)
        {
            Caption = 'Transaction No.';
        }
        field(4; "Receipt No."; Code[20])
        {
        }
        field(5; "Numero de Factura"; Code[20])
        {
        }
        field(6; Fecha; Date)
        {
        }
        field(7; Reimpresion; Integer)
        {
        }
        field(8; Hora; Time)
        {
        }
        field(9; "Nombre Cliente"; Text[50])
        {
        }
        field(10; DUI; Code[20])
        {
        }
        field(11; NIT; Text[20])
        {
        }
        field(12; "No. Extranjero"; Code[20])
        {
        }
        field(50000; Resolucion; Text[30])
        {
        }
        field(50001; Serie; Text[30])
        {
        }
        field(50002; Desde; Integer)
        {
        }
        field(50003; Hasta; Integer)
        {
        }
        field(50004; "Fecha Autorizacion"; Text[30])
        {
        }
    }

    keys
    {
        key(Key1; "Store No.", "POS Terminal No.", "Transaction No.")
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
    }
}

