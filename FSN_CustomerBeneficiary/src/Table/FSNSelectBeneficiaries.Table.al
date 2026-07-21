table 50059 SeleccionBeneficiario
{

    fields
    {
        field(2; "Card No."; Code[20])
        {
        }
        field(3; Name; Text[50])
        {
        }
        field(4; Relation; Code[20])
        {
        }
        field(5; Titular; Code[20])
        {
        }
    }

    keys
    {
        key(Key1; "Card No.")
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
    }
}

