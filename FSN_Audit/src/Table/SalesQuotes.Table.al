table 50015 "Sales Quotes"
{

    fields
    {
        field(1; Year; Text[30])
        {
        }
        field(2; Month; Option)
        {
            OptionMembers = ENERO,FEBRERO,MARZO,ABRIL,MAYO,JUNIO,JULIO,AGOSTO,SEPTIEMBRE,OCTUBRE,NOVIEMBRE,DICIEMBRE;
        }
        field(3; "Store No."; Code[10])
        {
        }
        field(4; Type; Option)
        {
            OptionMembers = CALL,POST,SUIZOS_CALL,SUIZOS_POST,CONVENIENCIA,CONVENIENCIA_CALL,CONVENIENCIA_PURA,DERMOCOSMETICA;
        }
        field(5; Total; Decimal)
        {
        }
        field(6; "User Id"; Code[10])
        {
        }
    }

    keys
    {
        key(Key1; Year, Month, "Store No.", Type)
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
    }
}

